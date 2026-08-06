# frozen_string_literal: true

module AdminSuite
  module Mcp
    module Authorization
      def self.readable_resources(actor:)
        return [] if AdminSuite.config.authorize.nil?

        Admin::Base::Resource.registered_resources
      end

      def self.denied_response
        ::MCP::Tool::Response.new(
          [{ type: "text", text: "Access denied" }],
          error: true
        )
      end

      def self.authorize_resource!(name:, actor:, action:)
        config = Admin::Base::Resource.registered_resources.find { |resource| resource.resource_name == name.to_s }
        return nil unless config && AdminSuite.config.authorize

        context = AdminSuite::AuthorizationContext.new(surface: :mcp)
        allowed = AdminSuite.config.authorize.call(actor: actor, action: action, resource: config, record: nil, context: context)
        allowed ? config : nil
      rescue StandardError
        nil
      end

      def self.error_response(message)
        ::MCP::Tool::Response.new([{ type: "text", text: message }], error: true)
      end
    end
  end
end
