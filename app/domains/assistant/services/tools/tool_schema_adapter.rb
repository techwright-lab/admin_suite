# frozen_string_literal: true

module Assistant
  module Tools
    # Builds provider-native tool schema payloads from Assistant::Tool records.
    class ToolSchemaAdapter
      def initialize(tools)
        @tools = Array(tools)
      end

      # @return [Array<Hash>] OpenAI Responses API tools payload
      def for_openai
        tools.map do |tool|
          schema = normalize_openai_json_schema(tool.arg_schema.presence || { type: "object", properties: {} })
          schema = sanitize_openai_top_level_schema(schema)
          {
            type: "function",
            # Responses API expects function tool definition fields at the top-level.
            # (Chat Completions uses {function: {...}}; Responses uses {name:, description:, parameters:}).
            name: tool.tool_key.to_s,
            description: tool.description.to_s,
            parameters: schema
          }
        end
      end

      # @return [Array<Hash>] Anthropic Messages API tools payload
      def for_anthropic
        tools.map do |tool|
          {
            name: tool.tool_key.to_s,
            description: tool.description.to_s,
            input_schema: tool.arg_schema.presence || { type: "object", properties: {} }
          }
        end
      end

      private

      attr_reader :tools

      # OpenAI validates JSON schema more strictly than our internal schema registry.
      # In particular, `type: "array"` must include an `items` schema.
      #
      # @param schema [Hash]
      # @return [Hash]
      def normalize_openai_json_schema(schema)
        return {} unless schema.is_a?(Hash)

        normalized = schema.deep_dup

        case normalized["type"] || normalized[:type]
        when "array"
          normalized["items"] ||= normalized[:items]
          normalized[:items] ||= normalized["items"]
          normalized["items"] ||= {}
          normalized[:items] ||= {}
          normalized["items"] = normalize_openai_json_schema(normalized["items"])
          normalized[:items] = normalized["items"]
        when "object"
          props = normalized["properties"] || normalized[:properties]
          if props.is_a?(Hash)
            props.each do |k, v|
              props[k] = normalize_openai_json_schema(v)
            end
          end
          normalized["properties"] = props if props
          normalized[:properties] = props if props
        end

        # Handle common combinators
        %w[anyOf oneOf allOf].each do |key|
          arr = normalized[key] || normalized[key.to_sym]
          next unless arr.is_a?(Array)
          normalized[key] = arr.map { |v| normalize_openai_json_schema(v) }
          normalized[key.to_sym] = normalized[key]
        end

        if (items = normalized["items"] || normalized[:items]).is_a?(Hash)
          normalized["items"] = normalize_openai_json_schema(items)
          normalized[:items] = normalized["items"]
        end

        normalized
      end

      # OpenAI Responses API function parameters currently reject top-level schema combinators.
      # Error example:
      # "Invalid schema ... must have type 'object' and not have 'oneOf'/'anyOf'/'allOf'/'enum'/'not' at the top level."
      #
      # We keep our richer internal schemas (used for server-side validation), but when sending tool
      # definitions to OpenAI we strip unsupported top-level keys. This prevents the entire request
      # from failing while still allowing nested enums, etc.
      #
      # @param schema [Hash]
      # @return [Hash]
      def sanitize_openai_top_level_schema(schema)
        return {} unless schema.is_a?(Hash)

        normalized = schema.deep_dup
        type = (normalized["type"] || normalized[:type]).to_s
        normalized["type"] = type.presence || "object"
        normalized[:type] = normalized["type"]

        # OpenAI requires top-level to be an object schema.
        unless normalized["type"] == "object"
          normalized["type"] = "object"
          normalized[:type] = "object"
        end

        %w[anyOf oneOf allOf not enum].each do |k|
          normalized.delete(k)
          normalized.delete(k.to_sym)
        end

        normalized
      end
    end
  end
end
