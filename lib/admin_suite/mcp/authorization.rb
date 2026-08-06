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
    end
  end
end
