# frozen_string_literal: true

module AdminSuite
  module Mcp
    module Tools
      class ListRecords < ::MCP::Tool
        tool_name "list_records"
        description "List records using the filters, search, and sort keys the resource declares."
        input_schema(
          properties: {
            resource: { type: "string" },
            q: { type: "string" },
            filters: { type: "object" },
            sort: { type: "string" },
            direction: { type: "string", enum: %w[asc desc] },
            page: { type: "integer" },
            per_page: { type: "integer" }
          },
          required: ["resource"]
        )

        def self.call(resource:, server_context:, q: nil, filters: {}, sort: nil, direction: nil, page: 1, per_page: nil)
          AdminSuite::Mcp.instrument(tool: "list_records", resource: resource, actor: server_context[:actor], request: server_context[:request]) do
            allowed = false
            config = Authorization.authorize_resource!(name: resource, actor: server_context[:actor], action: :read, request: server_context[:request])
            next [Authorization.denied_response, nil, false] unless config

            allowed = true
            query = build_query(config, filters, q:, sort:, direction:, per_page:)
            payload = response_payload(resource, config, query, page)
            response = ::MCP::Tool::Response.new([{ type: "text", text: Serializer.dump(payload) }])
            [response, payload[:rows].size, true]
          rescue StandardError => e
            Rails.logger&.warn("AdminSuite MCP list_records failed: #{e.class}: #{e.message}")
            [Authorization.error_response("list_records failed"), nil, allowed]
          end
        end

        def self.build_query(config, filters, **params)
          AdminSuite::Query.new(
            resource_config: config,
            params: (filters || {}).merge(params.except(:q), search: params[:q]).compact,
            max_page_size: AdminSuite.config.mcp.max_page_size
          )
        end

        def self.response_payload(resource, config, query, page)
          applied_page = page.to_i.clamp(1..)
          {
            resource: resource,
            page: applied_page,
            applied_per_page: query.per_page,
            rows: paginated(query, applied_page).map { |record| Serializer.index_row(record, config) }
          }
        end

        def self.paginated(query, page)
          offset = (page - 1) * query.per_page
          scope = query.scope
          return scope.offset(offset).limit(query.per_page) if scope.respond_to?(:offset)

          Array(scope).drop(offset).first(query.per_page)
        end
      end
    end
  end
end
