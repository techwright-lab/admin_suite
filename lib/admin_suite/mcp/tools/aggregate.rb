# frozen_string_literal: true

module AdminSuite
  module Mcp
    module Tools
      class Aggregate < ::MCP::Tool
        tool_name "aggregate"
        description "Counts and index stats for a resource under a filter set. Returns no records."
        input_schema(
          properties: {
            resource: { type: "string" },
            q: { type: "string" },
            filters: { type: "object" }
          },
          required: ["resource"]
        )

        def self.call(resource:, server_context:, q: nil, filters: {})
          AdminSuite::Mcp.instrument(tool: "aggregate", resource: resource, actor: server_context[:actor], request: server_context[:request], filters: filters, q: q) do
            allowed = false
            config = Authorization.authorize_resource!(name: resource, actor: server_context[:actor], action: :read, request: server_context[:request])
            next [Authorization.denied_response, nil, false] if config.nil?

            allowed = true
            params = (filters || {}).merge(search: q).compact
            scope = AdminSuite::Query.new(
              resource_config: config,
              params: params,
              max_page_size: AdminSuite.config.mcp.max_page_size
            ).scope
            payload = { resource: resource, count: scope.count, stats: stats_for(config, scope) }
            response = ::MCP::Tool::Response.new([{ type: "text", text: Serializer.dump(payload) }])
            [response, payload[:count], true]
          rescue StandardError => e
            Rails.logger&.warn("AdminSuite MCP aggregate failed: #{e.class}: #{e.message}")
            [Authorization.error_response("aggregate failed"), nil, allowed]
          end
        end

        def self.stats_for(config, scope)
          Array(config.index_config&.stats_list).each_with_object({}) do |stat, stats|
            stats[stat.name] = calculate(stat, scope)
          end
        end

        def self.calculate(stat, scope)
          stat.calculator.arity.zero? ? stat.calculator.call : stat.calculator.call(scope)
        rescue StandardError
          nil
        end
        private_class_method :calculate
      end
    end
  end
end
