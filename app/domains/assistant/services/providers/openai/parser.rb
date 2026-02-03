# frozen_string_literal: true

module Assistant
  module Providers
    module Openai
      # Normalizes OpenAI provider results into a stable internal shape.
      class Parser
        # @param provider_result [Hash]
        # @return [Hash]
        def self.normalize(provider_result)
          h = provider_result.is_a?(Hash) ? provider_result : {}
          {
            content: h[:content] || h["content"],
            tool_calls: h[:tool_calls] || h["tool_calls"] || [],
            response_id: h[:response_id] || h["response_id"]
          }.compact
        end
      end
    end
  end
end
