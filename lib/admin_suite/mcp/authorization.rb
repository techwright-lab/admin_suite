# frozen_string_literal: true

module AdminSuite
  module Mcp
    module Authorization
      DENIED_MESSAGE = "Not authorized, or no such resource."

      class << self
        def readable_resources(actor:, request: nil)
          return [] if AdminSuite.config.authorize.nil? || Auth.normalize_actor(actor).nil?

          resource_configs.select do |config|
            mcp_enabled?(config) && permitted?(config: config, actor: actor, action: :read, request: request)
          end
        end

        def authorize_resource!(name:, actor:, action:, request: nil)
          return nil if AdminSuite.config.authorize.nil? || Auth.normalize_actor(actor).nil?

          config = resource_configs.find { |resource| resource.resource_name == name.to_s }
          return nil unless config && mcp_enabled?(config)

          config if permitted?(config: config, actor: actor, action: action, request: request)
        end

        def authorize_record?(config:, actor:, record:, request: nil)
          return false if AdminSuite.config.authorize.nil? || Auth.normalize_actor(actor).nil?

          permitted?(config: config, actor: actor, record: record, action: :read, request: request)
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

        def permitted?(config:, actor:, action:, record: nil, request: nil)
          AdminSuite.config.authorize.call(
            actor: actor,
            action: action,
            resource: config,
            record: record,
            context: AdminSuite::AuthorizationContext.new(surface: :mcp, request: request)
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
