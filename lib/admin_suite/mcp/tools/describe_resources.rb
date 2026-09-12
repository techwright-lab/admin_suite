# frozen_string_literal: true

module AdminSuite
  module Mcp
    module Tools
      class DescribeResources < ::MCP::Tool
        tool_name "describe_resources"
        description "List the admin resources this actor may read, with their " \
                    "portals, declared fields, filters, sort keys, page size and actions."
        input_schema(properties: {}, required: [])

        def self.call(server_context:)
          AdminSuite::Mcp.instrument(tool: "describe_resources", actor: server_context[:actor], request: server_context[:request]) do
            allowed = false
            if AdminSuite.config.authorize.nil? || Auth.normalize_actor(server_context[:actor]).nil?
              [Authorization.denied_response, nil, false]
            else
              allowed = true
              payload = Authorization
                .readable_resources(actor: server_context[:actor], request: server_context[:request])
                .map { |config| describe(config) }
              response = ::MCP::Tool::Response.new([{ type: "text", text: Serializer.dump(payload) }])
              [response, payload.size, true]
            end
          rescue StandardError => e
            Rails.logger&.warn("AdminSuite MCP describe_resources failed: #{e.class}: #{e.message}")
            [Authorization.error_response("describe_resources failed"), nil, allowed]
          end
        end

        def self.describe(config)
          index = config.index_config
          {
            name: config.resource_name,
            model: config.model_class.to_s,
            portal: config.portal_name,
            section: config.section_name,
            fields: Array(index&.columns_list).map do |column|
              { name: column.name, label: column.header, type: column.type }
            end,
            filters: Array(index&.filters_list).map(&:name),
            sortable: Array(index&.sortable_fields),
            searchable: Array(index&.searchable_fields),
            default_page_size: index&.per_page,
            actions: declared_actions(config)
          }
        end

        def self.declared_actions(config)
          actions = config.actions_config
          return [] unless actions

          [
            *Array(actions.member_actions).map { |action| { name: action.name, kind: "member" } },
            *Array(actions.collection_actions).map { |action| { name: action.name, kind: "collection" } },
            *Array(actions.bulk_actions).map { |action| { name: action.name, kind: "bulk" } }
          ]
        end
        private_class_method :declared_actions
      end
    end
  end
end
