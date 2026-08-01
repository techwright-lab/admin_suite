# frozen_string_literal: true

module AdminSuite
  class ApplicationController < ::ApplicationController
    include ActionView::RecordIdentifier

    # Host apps often include global auth concerns in `ApplicationController`.
    # The engine authenticates via its own strategy layer instead, so it skips
    # the host filters named in `config.skip_host_before_actions`
    # (default: [:require_authentication], the Rails 8 authentication
    # generator's filter). Evaluated at class load — changing the config
    # requires a restart.
    Array(AdminSuite.config.skip_host_before_actions).each do |filter|
      skip_before_action filter, raise: false
    end

    before_action :admin_suite_authenticate!
    layout "admin_suite/application"

    helper AdminSuite::BaseHelper
    helper_method :admin_suite_actor, :navigation_items

    private

    FAIL_CLOSED_MESSAGE =
      "AdminSuite: access denied because no authentication is configured. " \
      "Set config.auth_strategy (e.g. :http_basic) or config.authenticate in " \
      "config/initializers/admin_suite.rb. To run without authentication in " \
      "development/test only, set config.allow_unauthenticated = true."

    # Fail-closed authentication. An unconfigured engine denies every request.
    #
    # @return [void]
    def admin_suite_authenticate!
      strategy = AdminSuite.resolved_auth_strategy

      if strategy.nil?
        if AdminSuite.config.allow_unauthenticated && !Rails.env.production?
          @admin_suite_actor = nil
          return
        end
        render plain: FAIL_CLOSED_MESSAGE, status: :forbidden
        return
      end

      actor = strategy.authenticate!(self)
      return if performed?

      if actor
        @admin_suite_actor = actor
      else
        head :forbidden
      end
    end

    # Returns the actor for actions/auditing/authorization.
    #
    # Strategy-provided actor wins; the legacy `config.current_actor` lambda
    # remains the fallback. The HostHook `true` sentinel is never exposed.
    #
    # @return [Object, nil]
    def admin_suite_actor
      if defined?(@admin_suite_actor) && @admin_suite_actor
        # HostHook's `true` sentinel means it already consulted current_actor
        # this request and found nothing — don't consult it again.
        return nil if @admin_suite_actor.equal?(true)
        return @admin_suite_actor
      end

      return @admin_suite_fallback_actor if defined?(@admin_suite_fallback_actor)

      @admin_suite_fallback_actor =
        begin
          AdminSuite.config.current_actor&.call(self)
        rescue StandardError
          nil
        end
    end

    # Loads resource definition files when needed (runs in all environments).
    #
    # @return [void]
    def ensure_resources_loaded!
      AdminSuite::DefinitionLoader.load!(:resources)
    end

    # Loads portal definition files in development (safe to call per-request).
    #
    # @return [void]
    def ensure_portals_loaded!
      AdminSuite::DefinitionLoader.load!(:portals)
    end

    # Loads the root dashboard definition files (safe to call per-request).
    #
    # Host apps typically define this in:
    # - `config/admin_suite/dashboard.rb`
    # - `app/admin_suite/dashboard.rb`
    #
    # @return [void]
    def ensure_root_dashboard_loaded!
      AdminSuite::DefinitionLoader.load!(:dashboards)
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

        # Declared sections appear even before any resource is assigned to
        # them, so their label/order take effect immediately.
        definition.sections.each do |section_key, section_definition|
          navigation[key.to_sym][:sections][section_key] ||=
            { label: section_key.to_s.humanize, order: 100, items: [] }.merge(section_definition.to_nav_meta)
        end
      end

      Admin::Base::Resource.registered_resources.each do |resource|
        next unless resource.portal_name && resource.section_name

        portal = resource.portal_name.to_sym
        section = resource.section_name.to_sym

        navigation[portal] ||= { label: portal.to_s.humanize, order: 100, sections: {} }
        navigation[portal][:sections][section] ||= begin
          declared = AdminSuite::PortalRegistry.all[portal]&.sections&.[](section)
          { label: section.to_s.humanize, order: 100, items: [] }.merge(declared&.to_nav_meta || {})
        end

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
