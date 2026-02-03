# frozen_string_literal: true

module AdminSuite
  class ApplicationController < ::ApplicationController
    include ActionView::RecordIdentifier

    before_action :admin_suite_authenticate!
    layout "admin_suite/application"

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

    # Loads resource definition files in development when needed.
    #
    # @return [void]
    def ensure_resources_loaded!
      return unless Rails.env.development?
      return if Admin::Base::Resource.registered_resources.any?

      Array(AdminSuite.config.resource_globs).flat_map { |g| Dir[g] }.uniq.each do |file|
        require file
      end
    rescue NameError
      # Ensure base DSL is loaded first.
      require "admin/base/resource"
      retry
    end

    # Builds the navigation structure from registered resources.
    #
    # @return [Hash]
    def navigation_items
      ensure_resources_loaded!

      portals = AdminSuite.config.portals
      navigation = portals.each_with_object({}) do |(key, meta), h|
        h[key.to_sym] = meta.symbolize_keys.merge(sections: {})
      end

      Admin::Base::Resource.registered_resources.each do |resource|
        next unless resource.portal_name && resource.section_name

        portal = resource.portal_name.to_sym
        section = resource.section_name.to_sym

        navigation[portal] ||= { label: portal.to_s.humanize, order: 100, sections: {} }
        navigation[portal][:sections][section] ||= { label: section.to_s.humanize, items: [] }
        navigation[portal][:sections][section][:items] << {
          label: resource.human_name_plural,
          path: resources_path(portal: portal, resource_name: resource.resource_name_plural),
          resource: resource
        }
      end

      navigation
    end
  end
end
