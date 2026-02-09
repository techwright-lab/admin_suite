# frozen_string_literal: true

begin
  require "lucide-rails"
rescue LoadError
  # Host app may choose a different icon provider via `AdminSuite.config.icon_renderer`.
end

require "pagy"

require "admin_suite/version"
require "admin_suite/configuration"
require "admin_suite/markdown_renderer"
require "admin_suite/theme_palette"
require "admin_suite/portal_registry"
require "admin_suite/portal_definition"
require "admin_suite/ui/form_field_renderer"
require "admin_suite/ui/show_value_formatter"
require "admin_suite/engine"

module AdminSuite
  class << self
    # @return [AdminSuite::Configuration]
    def config
      @config ||= Configuration.new
    end

    # @yieldparam config [AdminSuite::Configuration]
    # @return [AdminSuite::Configuration]
    def configure
      yield(config)
      config
    end

    # Defines (or updates) a portal using a Ruby DSL.
    #
    # Host apps typically place these in:
    # - `config/admin_suite/portals/*.rb` (recommended; not a Zeitwerk autoload path)
    # - `app/admin_suite/portals/*.rb` (supported; AdminSuite ignores for Zeitwerk)
    # - `app/admin/portals/*.rb` (supported; AdminSuite will ignore for Zeitwerk if files contain `AdminSuite.portal`)
    #
    # @param key [Symbol, String]
    # @yield Portal definition DSL
    # @return [AdminSuite::PortalDefinition]
    def portal(key, &block)
      definition = PortalDefinition.new(key)
      definition.instance_eval(&block) if block_given?
      PortalRegistry.register(definition)
      definition
    end

    # @return [Hash{Symbol=>AdminSuite::PortalDefinition}]
    def portal_definitions
      PortalRegistry.all
    end

    # Defines (or updates) the root dashboard shown at the engine root (`/`).
    #
    # This uses the same dashboard DSL as portal dashboards.
    #
    # Host apps typically place these in:
    # - `config/admin_suite/dashboard.rb` (recommended; not a Zeitwerk autoload path)
    # - `app/admin_suite/dashboard.rb` (supported; AdminSuite ignores for Zeitwerk)
    #
    # @yield Dashboard definition DSL
    # @return [AdminSuite::UI::DashboardDefinition]
    def root_dashboard(&block)
      config.root_dashboard_definition ||= UI::DashboardDefinition.new
      UI::DashboardDSL.new(config.root_dashboard_definition).instance_eval(&block) if block_given?
      config.root_dashboard_definition
    end

    # @return [AdminSuite::UI::DashboardDefinition, nil]
    def root_dashboard_definition
      config.root_dashboard_definition
    end

    # Clears the root dashboard definition (useful for development reloads).
    #
    # @return [void]
    def reset_root_dashboard!
      config.root_dashboard_definition = nil
      config.root_dashboard_loaded = false
    rescue StandardError
      # best-effort
    end
  end
end
