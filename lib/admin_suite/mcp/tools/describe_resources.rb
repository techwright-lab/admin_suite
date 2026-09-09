# frozen_string_literal: true

module AdminSuite
  module Mcp
    module Tools
      class DescribeResources < ::MCP::Tool
        tool_name "describe_resources"
        description "List the admin resources this actor may read, with their " \
                    "declared fields, filters, sort keys and page size."
        input_schema(properties: {}, required: [])

        def self.call(server_context:)
          AdminSuite::Mcp.instrument(tool: "describe_resources", actor: server_context[:actor], request: server_context[:request]) do
            if AdminSuite.config.authorize.nil? || Auth.normalize_actor(server_context[:actor]).nil?
              [Authorization.denied_response, nil, false]
            else
              payload = Authorization
                .readable_resources(actor: server_context[:actor], request: server_context[:request])
                .map { |config| describe(config) }
              response = ::MCP::Tool::Response.new([{ type: "text", text: JSON.pretty_generate(payload) }])
              [response, payload.size, true]
            end
          end
        end

        def self.describe(config)
          index = config.index_config
          {
            name: config.resource_name,
            model: config.model_class.to_s,
            fields: Array(index&.columns_list).map do |column|
              { name: column.name, label: column.header, type: column.type }
            end,
            filters: Array(index&.filters_list).map(&:name),
            sortable: Array(index&.sortable_fields),
            searchable: Array(index&.searchable_fields),
            default_page_size: index&.per_page
          }
        end
      end
    end
  end
end
