# frozen_string_literal: true

module Assistant
  module Chat
    module Components
      class LlmResponder
        def initialize(user:, trace_id:, question:, context:, allowed_tools:, thread: nil)
          @user = user
          @trace_id = trace_id
          @question = question.to_s
          @context = context
          @allowed_tools = allowed_tools
          @thread = thread
        end

        def call
          prompt = PromptBuilder.new(
            context: context,
            question: question,
            allowed_tools: allowed_tools,
            conversation_history: build_conversation_history
          ).build
          system_prompt = Ai::AssistantSystemPrompt.active_prompt&.prompt_template || Ai::AssistantSystemPrompt.default_prompt_template

          provider_chain = LlmProviders::ProviderConfigHelper.all_providers
          last_error = nil

          provider_chain.each do |provider_name|
            provider = provider_for(provider_name)
            next unless provider&.available?

            logger = Ai::ApiLoggerService.new(
              operation_type: :assistant_chat,
              loggable: user,
              provider: provider.provider_name,
              model: provider.model_name,
              llm_prompt: Ai::AssistantSystemPrompt.active_prompt
            )

            result = logger.record(prompt: prompt, content_size: prompt.bytesize) do
              provider.run(prompt, system_message: system_prompt, temperature: 0.2, max_tokens: 1200)
            end

            if result[:error].present?
              last_error = result[:error]
              next
            end

            parsed = parse_assistant_json(result[:content])
            answer = parsed[:answer].presence || "I couldn't generate a response. Please try again."
            tool_calls = Array(parsed[:tool_calls]).map { |tc| normalize_tool_call(tc) }.compact

            return {
              answer: answer,
              tool_calls: tool_calls,
              llm_api_log: Ai::LlmApiLog.find(result[:llm_api_log_id]),
              latency_ms: result[:latency_ms],
              status: "success",
              metadata: {
                trace_id: trace_id,
                provider: provider.provider_name,
                model: provider.model_name,
                tool_calls: tool_calls
              }
            }
          end

          fallback_provider = provider_for(provider_chain.first)
          logger = Ai::ApiLoggerService.new(
            operation_type: :assistant_chat,
            loggable: user,
            provider: (fallback_provider&.provider_name || "unknown"),
            model: (fallback_provider&.model_name || "unknown"),
            llm_prompt: Ai::AssistantSystemPrompt.active_prompt
          )

          failed = logger.record(prompt: prompt, content_size: prompt.bytesize) do
            { content: nil, input_tokens: nil, output_tokens: nil, confidence: nil, error: (last_error || "All providers failed") }
          end

          {
            answer: "Sorry — I ran into an issue generating a response. Please try again.",
            tool_calls: [],
            llm_api_log: Ai::LlmApiLog.find(failed[:llm_api_log_id]),
            latency_ms: failed[:latency_ms],
            status: "error",
            metadata: { trace_id: trace_id, error: last_error }
          }
        end

        private

        attr_reader :user, :trace_id, :question, :context, :allowed_tools, :thread

        # Builds conversation history from thread messages.
        # Excludes the current user message (which is passed separately as question).
        #
        # @return [Array<Hash>] array of {role:, content:} hashes
        def build_conversation_history
          return [] if thread.nil?

          # Get all messages except the most recent user message (current question)
          messages = thread.messages.chronological.to_a

          # Remove the last user message if it matches the current question
          if messages.last&.role == "user" && messages.last&.content&.strip == question.strip
            messages = messages[0..-2]
          end

          messages.map do |msg|
            { role: msg.role, content: msg.content }
          end
        end

        def parse_assistant_json(text)
          return {} if text.blank?
          json = text.to_s.strip
          match = json.match(/\{.*\}/m)
          json = match[0] if match
          JSON.parse(json).deep_symbolize_keys
        rescue JSON::ParserError
          { answer: text.to_s, tool_calls: [] }
        end

        def normalize_tool_call(tc)
          h = tc.is_a?(Hash) ? tc : {}
          tool_key = h[:tool_key] || h["tool_key"]
          args = h[:args] || h["args"] || {}
          return nil if tool_key.blank?
          { tool_key: tool_key.to_s, args: args.is_a?(Hash) ? args : {} }
        end

        def provider_for(provider_name)
          case provider_name.to_s.downcase
          when "openai" then LlmProviders::OpenaiProvider.new
          when "anthropic" then LlmProviders::AnthropicProvider.new
          when "ollama" then LlmProviders::OllamaProvider.new
          else nil
          end
        end
      end
    end
  end
end
