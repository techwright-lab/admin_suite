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
          return Authorization.denied_response if AdminSuite.config.authorize.nil?

          payload = Authorization
            .readable_resources(actor: server_context[:actor])
            .map { |config| describe(config) }

          ::MCP::Tool::Response.new([{ type: "text", text: JSON.pretty_generate(payload) }])
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
