# frozen_string_literal: true

module AdminSuite
  class ApplicationController < ::ApplicationController
    include ActionView::RecordIdentifier

    # Host apps often include global auth concerns in `ApplicationController`.
    # The engine uses `AdminSuite.config.authenticate` instead, so we defensively
    # skip any host-level authentication before_actions that would otherwise
    # redirect to missing routes (e.g. `new_session_path`).
    skip_before_action :require_authentication, raise: false

    before_action :admin_suite_authenticate!
    layout "admin_suite/application"

    helper AdminSuite::BaseHelper
    helper_method :admin_suite_actor, :navigation_items

    private

    # Runs the host-app authentication hook (if configured).
    #
    # @return [void]
    def admin_suite_authenticate!
      hook = AdminSuite.config.authenticate
      hook&.call(self)
    end

    # Returns the configured actor for actions/auditing/authorization.
    #
    # @return [Object, nil]
    def admin_suite_actor
      AdminSuite.config.current_actor&.call(self)
    rescue StandardError
      nil
    end

    # Loads resource definition files when needed (runs in all environments).
    #
    # @return [void]
    def ensure_resources_loaded!
      require "admin/base/resource" unless defined?(Admin::Base::Resource)
      return if Admin::Base::Resource.registered_resources.any?

      Array(AdminSuite.config.resource_globs).flat_map { |g| Dir[g] }.uniq.each do |file|
        require file
      end
    rescue NameError
      # Ensure base DSL is loaded first.
      require "admin/base/resource"
      retry
    end

    # Loads portal definition files in development (safe to call per-request).
    #
    # @return [void]
    def ensure_portals_loaded!
      globs = Array(AdminSuite.config.portal_globs).flat_map { |g| Dir[g] }.uniq
      return if globs.empty?

      if Rails.env.development?
        # Re-evaluate definitions on each request in development.
        AdminSuite::PortalRegistry.reset!
        globs.each { |file| load file }
      else
        # In non-dev, load once (typically at boot / first request).
        return if AdminSuite::PortalRegistry.all.any?
        globs.each { |file| require file }
      end
    rescue NameError
      require "admin_suite"
      retry
    end

    # Loads the root dashboard definition files (safe to call per-request).
    #
    # Host apps typically define this in:
    # - `config/admin_suite/dashboard.rb`
    # - `app/admin_suite/dashboard.rb`
    #
    # @return [void]
    def ensure_root_dashboard_loaded!
      if Rails.env.development?
        globs = Array(AdminSuite.config.dashboard_globs).flat_map { |g| Dir[g] }.uniq
        # Re-evaluate dashboard layout on each request in development.
        # Always reset, even when no files match, so removed dashboards are cleared.
        AdminSuite.reset_root_dashboard!
        globs.each { |file| load file }
      else
        # In non-dev, load once.
        return if AdminSuite.config.root_dashboard_loaded
        globs = Array(AdminSuite.config.dashboard_globs).flat_map { |g| Dir[g] }.uniq
        if globs.empty?
          # Avoid hitting the filesystem on every request when no dashboard files exist.
          AdminSuite.config.root_dashboard_loaded = true
          return
        end
        globs.each { |file| require file }
        AdminSuite.config.root_dashboard_loaded = true
      end
    rescue NameError
      require "admin_suite"
      retry
    end

    # Builds the navigation structure from registered resources.
    #
    # @return [Hash]
    def navigation_items
      ensure_resources_loaded!
      ensure_portals_loaded!

      portals = AdminSuite.config.portals
      navigation = portals.each_with_object({}) do |(key, meta), h|
        meta = meta.respond_to?(:symbolize_keys) ? meta.symbolize_keys : {}
        h[key.to_sym] = meta.merge(sections: {})
      end

      # Merge any DSL-defined portal metadata into navigation.
      AdminSuite::PortalRegistry.all.each do |key, definition|
        navigation[key.to_sym] ||= { label: key.to_s.humanize, order: 100, sections: {} }
        navigation[key.to_sym].merge!(definition.to_nav_meta)
        navigation[key.to_sym][:sections] ||= {}
      end

      Admin::Base::Resource.registered_resources.each do |resource|
        next unless resource.portal_name && resource.section_name

        portal = resource.portal_name.to_sym
        section = resource.section_name.to_sym

        navigation[portal] ||= { label: portal.to_s.humanize, order: 100, sections: {} }
        navigation[portal][:sections][section] ||= { label: section.to_s.humanize, items: [] }

        label = resource.nav_label.presence || resource.human_name_plural
        navigation[portal][:sections][section][:items] << {
          label: label,
          path: resources_path(portal: portal, resource_name: resource.resource_name_plural),
          resource: resource,
          icon: resource.nav_icon,
          order: resource.nav_order
        }
      end

      navigation
    end
  end
end
