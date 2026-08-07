# frozen_string_literal: true

module AdminSuite
  module Mcp
    module Authorization
      DENIED_MESSAGE = "Not authorized, or no such resource."

      class << self
        def readable_resources(actor:)
          return [] if AdminSuite.config.authorize.nil?

          resource_configs.select do |config|
            mcp_enabled?(config) && permitted?(config: config, actor: actor, action: :read)
          end
        end

        def authorize_resource!(name:, actor:, action:)
          return nil if AdminSuite.config.authorize.nil?

          config = resource_configs.find { |resource| resource.resource_name == name.to_s }
          return nil unless config && mcp_enabled?(config)

          config if permitted?(config: config, actor: actor, action: action)
        end

        def denied_response
          ::MCP::Tool::Response.new([{ type: "text", text: DENIED_MESSAGE }], error: true)
        end

        def error_response(message)
          ::MCP::Tool::Response.new([{ type: "text", text: message }], error: true)
        end

        private

        def resource_configs
          AdminSuite::DefinitionLoader.load!(:resources)
          Admin::Base::Resource.registered_resources
        end

        def mcp_enabled?(config)
          !config.respond_to?(:mcp_enabled?) || config.mcp_enabled?
        end

        def permitted?(config:, actor:, action:)
          AdminSuite.config.authorize.call(
            actor: actor,
            action: action,
            resource: config,
            record: nil,
            context: AdminSuite::AuthorizationContext.new(surface: :mcp)
          )
        rescue StandardError => error
          Rails.logger&.warn(
            "AdminSuite: MCP authorize hook raised #{error.class}: #{error.message}; denying."
          )
          false
        end
      end
    end
  end
end
