# frozen_string_literal: true

require "dry/schema"

module Assistant
  module Contracts
    # Runtime contract for a normalized tool call produced by an LLM provider.
    #
    # Expected input (symbol or string keys):
    # - tool_key: String
    # - args: Hash
    # - provider_name: String
    # - provider_tool_call_id: String (OpenAI call_id / Anthropic tool_use_id)
    class ToolCallContract
      Schema = Dry::Schema.Params do
        required(:tool_key).filled(:string)
        required(:args).hash
        required(:provider_name).filled(:string)
        required(:provider_tool_call_id).filled(:string)
      end

      # @param tool_call [Hash]
      # @return [Dry::Schema::Result]
      def self.call(tool_call)
        Schema.call(tool_call)
      end
    end
  end
end
