# frozen_string_literal: true

require "dry/schema"

module Assistant
  module Contracts
    # Runtime contract for a tool result that will be sent back to an LLM provider.
    class ToolResultContract
      Schema = Dry::Schema.Params do
        required(:provider_tool_call_id).filled(:string)
        required(:tool_key).filled(:string)
        required(:success).filled(:bool)
        optional(:data).value(:any)
        optional(:error).maybe(:string)
      end

      # @param tool_result [Hash]
      # @return [Dry::Schema::Result]
      def self.call(tool_result)
        Schema.call(tool_result)
      end
    end
  end
end
