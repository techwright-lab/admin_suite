# frozen_string_literal: true

module Assistant
  module Providers
    # ProviderRouter centralizes provider-specific request building for assistant chat/tool calling.
    #
    # This keeps provider branching out of chat orchestration components.
    class ProviderRouter
      # @param thread [Assistant::ChatThread, nil]
      # @param question [String]
      # @param system_prompt [String]
      # @param allowed_tools [Array<Assistant::Tool>]
      # @param media [Array<Hash>]
      def initialize(thread:, question:, system_prompt:, allowed_tools:, media: [])
        @thread = thread
        @question = question.to_s
        @system_prompt = system_prompt.to_s
        @allowed_tools = Array(allowed_tools)
        @media = Array(media).compact
      end

      # @param provider [Object] LlmProviders::*Provider instance
      # @return [Hash] provider.run result
      def call(provider:)
        provider_name = provider.provider_name.to_s.downcase

        case provider_name
        when "openai"
          options = Providers::Openai::MessageBuilder.new(
            thread: thread,
            question: question,
            system_prompt: system_prompt,
            allowed_tools: allowed_tools,
            media: media
          ).build_chat_options
          provider.run(nil, options)
        when "anthropic"
          options = Providers::Anthropic::MessageBuilder.new(
            thread: thread,
            question: question,
            system_prompt: system_prompt,
            allowed_tools: allowed_tools,
            media: media
          ).build_chat_options
          provider.run(nil, options)
        else
          # Legacy prompt-based providers (not a focus right now).
          legacy_prompt = Assistant::Chat::Components::PromptBuilder.new(
            context: {},
            question: question,
            allowed_tools: allowed_tools,
            conversation_history: []
          ).build
          provider.run(legacy_prompt, system_message: system_prompt, temperature: 0.2, max_tokens: 1200)
        end
      end

      # @param provider [Object] LlmProviders::*Provider instance
      # @return [String] JSON payload for logging
      def request_payload_for_log(provider:)
        provider_name = provider.provider_name.to_s.downcase

        payload =
          case provider_name
          when "openai"
            Providers::Openai::MessageBuilder.new(
              thread: thread,
              question: question,
              system_prompt: system_prompt,
              allowed_tools: allowed_tools,
              media: media
            ).build_log_payload
          when "anthropic"
            Providers::Anthropic::MessageBuilder.new(
              thread: thread,
              question: question,
              system_prompt: system_prompt,
              allowed_tools: allowed_tools,
              media: media
            ).build_log_payload
          else
            { provider: provider.provider_name, system: system_prompt.to_s, question: question.to_s, tools_count: allowed_tools.size }
          end

        payload.to_json
      end

      private

      attr_reader :thread, :question, :system_prompt, :allowed_tools, :media
    end
  end
end
