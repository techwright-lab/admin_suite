# frozen_string_literal: true

module AdminSuite
  module Mcp
    TOOLS = [
      AdminSuite::Mcp::Tools::DescribeResources,
      AdminSuite::Mcp::Tools::ListRecords
    ].freeze

    # A fresh server is built for each request, so its advertised tool list is
    # derived from the current fail-closed authorization posture rather than
    # cached across actors or requests.
    def self.server_for(actor:, request: nil)
      tools = AdminSuite.config.authorize.nil? ? [] : TOOLS

      ::MCP::Server.new(
        name: "admin_suite",
        version: AdminSuite::VERSION,
        tools: tools,
        server_context: { actor: actor, request: request }
      )
    end
  end
end
