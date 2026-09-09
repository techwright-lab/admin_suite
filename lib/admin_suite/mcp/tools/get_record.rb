# frozen_string_literal: true

module AdminSuite
  module Mcp
    module Tools
      class GetRecord < ::MCP::Tool
        tool_name "get_record"
        description "One record by id, using the resource's show-page field set."
        input_schema(
          properties: { resource: { type: "string" }, id: { type: "string" } },
          required: %w[resource id]
        )

        def self.call(resource:, id:, server_context:)
          AdminSuite::Mcp.instrument(tool: "get_record", resource: resource, actor: server_context[:actor]) do
            config = Authorization.authorize_resource!(name: resource, actor: server_context[:actor], action: :read, request: server_context[:request])
            next [Authorization.denied_response, nil, false] if config.nil?

            record = config.model_class.find_by(id: id)
            next [Authorization.denied_response, nil, false] if record.nil?
            unless Authorization.authorize_record?(config: config, actor: server_context[:actor], record: record, request: server_context[:request])
              next [Authorization.denied_response, nil, false]
            end

            payload = {
              resource: resource, id: id, fields: Serializer.show_payload(record, config),
              associations: Serializer.associations_payload(record, config, max_rows: AdminSuite.config.mcp.max_page_size)
            }
            response = ::MCP::Tool::Response.new([{ type: "text", text: JSON.pretty_generate(payload) }])
            [response, 1, true]
          rescue StandardError => e
            Rails.logger&.warn("AdminSuite MCP get_record failed: #{e.class}: #{e.message}")
            [Authorization.error_response("get_record failed"), nil, true]
          end
        end
      end
    end
  end
end
