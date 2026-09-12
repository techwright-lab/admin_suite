# frozen_string_literal: true

module AdminSuite
  module Mcp
    TOOLS = [
      AdminSuite::Mcp::Tools::DescribeResources,
      AdminSuite::Mcp::Tools::ListRecords,
      AdminSuite::Mcp::Tools::GetRecord,
      AdminSuite::Mcp::Tools::Aggregate
    ].freeze

    # A fresh server is built for each request, so its advertised tool list is
    # derived from the current fail-closed authorization posture rather than
    # cached across actors or requests.
    def self.server_for(actor:, request: nil)
      tools = AdminSuite.config.authorize.nil? || Auth.normalize_actor(actor).nil? ? [] : TOOLS

      ::MCP::Server.new(
        name: "admin_suite",
        version: AdminSuite::VERSION,
        tools: tools,
        server_context: { actor: actor, request: request }
      )
    end

    def self.instrument(tool:, resource: nil, actor: nil, action: :read, request: nil, filters: nil, q: nil)
      payload = {
        tool: tool,
        resource: resource,
        actor_type: actor&.class&.name,
        actor_id: actor.respond_to?(:id) ? actor.id.to_s : nil,
        request_id: request&.request_id,
        action: action,
        filters: filters,
        q: q,
        allowed: false,
        error: true,
        result_count: nil
      }
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      ActiveSupport::Notifications.instrument("admin_suite.mcp.tool_call", payload) do
        response, count, allowed = yield
        payload[:allowed] = allowed
        payload[:result_count] = count
        payload[:error] = response.error?
        response
      ensure
        payload[:duration_ms] = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
      end
    end
  end
end
