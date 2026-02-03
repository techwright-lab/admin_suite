# frozen_string_literal: true

module Assistant
  module Providers
    module Anthropic
      # Normalizes Anthropic provider results into a stable internal shape.
      class Parser
        # @param provider_result [Hash]
        # @return [Hash]
        def self.normalize(provider_result)
          h = provider_result.is_a?(Hash) ? provider_result : {}
          {
            content: h[:content] || h["content"],
            tool_calls: h[:tool_calls] || h["tool_calls"] || [],
            content_blocks: h[:content_blocks] || h["content_blocks"],
            message_id: h[:message_id] || h["message_id"]
          }.compact
        end
      end
    end
  end
end
