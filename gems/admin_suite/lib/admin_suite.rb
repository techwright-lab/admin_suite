# frozen_string_literal: true

require "admin_suite/version"
require "admin_suite/configuration"
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
    # Host apps typically place these in `app/admin/portals/*.rb`.
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
  end
end
