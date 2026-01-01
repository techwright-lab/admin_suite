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
          system_prompt = active_system_prompt
          provider_chain = LlmProviders::ProviderConfigHelper.all_providers

          last_error = nil
          last_failure = nil
          provider_chain.each do |provider_name|
            res = attempt_provider(provider_name: provider_name, system_prompt: system_prompt)
            if res[:status] == "success"
              return res
            end

            last_error = res[:error].presence || last_error
            last_failure = res if res[:status] == "error"
          end

          build_fallback_error(
            provider_chain: provider_chain,
            system_prompt: system_prompt,
            last_error: last_error,
            last_failure: last_failure
          )
        end

        private

        attr_reader :user, :trace_id, :question, :context, :allowed_tools, :thread

        def active_system_prompt
          Ai::AssistantSystemPrompt.active_prompt&.prompt_template || Ai::AssistantSystemPrompt.default_prompt_template
        end

        def attempt_provider(provider_name:, system_prompt:)
          provider = provider_for(provider_name)
          return { status: "skipped", error: nil } unless provider&.available?

          logger = Ai::ApiLoggerService.new(
            operation_type: :assistant_chat,
            loggable: user,
            provider: provider.provider_name,
            model: provider.model_name,
            llm_prompt: Ai::AssistantSystemPrompt.active_prompt
          )

          request_for_log = build_request_for_log(provider_name: provider.provider_name, system_prompt: system_prompt)
          result = logger.record(prompt: request_for_log, content_size: request_for_log.bytesize) do
            call_provider(provider: provider, provider_name: provider.provider_name, system_prompt: system_prompt)
          end

          if result[:error].present?
            return {
              status: "error",
              error: result[:error],
              error_type: result[:error_type],
              provider: provider.provider_name,
              model: provider.model_name,
              llm_api_log_id: result[:llm_api_log_id]
            }
          end

          build_success_response(provider: provider, result: result)
        end

        def build_success_response(provider:, result:)
          tool_calls = normalize_and_validate_tool_calls(result[:tool_calls], provider: provider.provider_name)

          answer, pending_tool_followup = finalize_answer(
            answer: result[:content].to_s,
            tool_calls: tool_calls
          )

          {
            answer: answer,
            tool_calls: tool_calls,
            llm_api_log: Ai::LlmApiLog.find(result[:llm_api_log_id]),
            latency_ms: result[:latency_ms],
            status: "success",
            metadata: {
              trace_id: trace_id,
              provider: provider.provider_name,
              model: provider.model_name,
              tool_calls: tool_calls,
              provider_state: extract_provider_state(provider: provider.provider_name, result: result),
              provider_content_blocks: (provider.provider_name.to_s.downcase == "anthropic" ? result[:content_blocks] : nil),
              pending_tool_followup: pending_tool_followup
            }.compact
          }
        end

        def normalize_and_validate_tool_calls(raw_tool_calls, provider:)
          calls = Array(raw_tool_calls).map { |tc| normalize_tool_call(tc, provider: provider) }.compact

          calls.select do |tc|
            contract = Assistant::Contracts::ToolCallContract.call(tc)
            next true if contract.success?

            Rails.logger.warn("[LlmResponder] Dropping invalid tool_call: errors=#{contract.errors.to_h.inspect} tool_call=#{tc.inspect}")
            false
          end
        end

        def finalize_answer(answer:, tool_calls:)
          pending_tool_followup = pending_tool_followup?(tool_calls: tool_calls)

          if pending_tool_followup
            return [ "Working on it — I’m fetching the latest info now.", true ]
          end

          if answer.strip.blank? && tool_calls.any?
            answer = "I have some proposed actions for you to review below."
          end

          answer = "I couldn't generate a response. Please try again." if answer.strip.blank?

          [ answer, false ]
        end

        def pending_tool_followup?(tool_calls:)
          return false if tool_calls.blank?

          tool_calls.any? do |tc|
            tool = allowed_tools.find { |t| t.tool_key == tc[:tool_key] }
            next false if tool.nil?

            (tool.requires_confirmation || tool.risk_level != "read_only") == false
          end
        end

        def build_fallback_error(provider_chain:, system_prompt:, last_error:, last_failure:)
          error_message = last_error || "All providers failed"

          # Prefer the real provider attempt log (it has provider/model/error_type/raw_response)
          # so the turn links to the useful failure details.
          if last_failure&.dig(:llm_api_log_id).present?
            log = Ai::LlmApiLog.find(last_failure[:llm_api_log_id])
            return {
              answer: "Sorry — I ran into an issue generating a response. Please try again.",
              tool_calls: [],
              llm_api_log: log,
              latency_ms: nil,
              status: "error",
              metadata: {
                trace_id: trace_id,
                provider: last_failure[:provider] || log.provider || "unknown",
                model: last_failure[:model] || log.model || "unknown",
                error: error_message,
                error_type: last_failure[:error_type] || log.error_type
              }.compact
            }
          end

          # No provider attempt log exists (e.g., all providers were unavailable). Record a synthetic log.
          fallback_provider = provider_for(provider_chain.first)
          logger = Ai::ApiLoggerService.new(
            operation_type: :assistant_chat,
            loggable: user,
            provider: (fallback_provider&.provider_name || "unknown"),
            model: (fallback_provider&.model_name || "unknown"),
            llm_prompt: Ai::AssistantSystemPrompt.active_prompt
          )

          request_for_log = build_request_for_log(provider_name: (fallback_provider&.provider_name || "unknown"), system_prompt: system_prompt)
          failed = logger.record(prompt: request_for_log, content_size: request_for_log.bytesize) do
            { content: nil, input_tokens: nil, output_tokens: nil, confidence: nil, error: error_message, error_type: "all_providers_failed" }
          end

          {
            answer: "Sorry — I ran into an issue generating a response. Please try again.",
            tool_calls: [],
            llm_api_log: Ai::LlmApiLog.find(failed[:llm_api_log_id]),
            latency_ms: failed[:latency_ms],
            status: "error",
            metadata: {
              trace_id: trace_id,
              provider: (fallback_provider&.provider_name || "unknown"),
              model: (fallback_provider&.model_name || "unknown"),
              error: error_message,
              error_type: "all_providers_failed"
            }.compact
          }
        end

        def call_provider(provider:, provider_name:, system_prompt:)
          case provider_name.to_s.downcase
          when "openai"
            openai_call(provider: provider, system_prompt: system_prompt)
          when "anthropic"
            anthropic_call(provider: provider, system_prompt: system_prompt)
          else
            legacy_prompt = PromptBuilder.new(
              context: context,
              question: question,
              allowed_tools: allowed_tools,
              conversation_history: build_conversation_history_for_legacy_prompt
            ).build
            provider.run(legacy_prompt, system_message: system_prompt, temperature: 0.2, max_tokens: 1200)
          end
        end

        def openai_call(provider:, system_prompt:)
          tools = Assistant::Tools::ToolSchemaAdapter.new(allowed_tools).for_openai
          previous_response_id = last_openai_response_id

          messages =
            if previous_response_id.present?
              [ { role: "user", content: question } ]
            else
              # No provider-native conversation state available; send a full message list.
              openai_messages = build_provider_messages(max_messages: 20)
              [ { role: "system", content: system_prompt } ] + openai_messages
            end

          provider.run(
            nil,
            messages: messages,
            tools: tools,
            previous_response_id: previous_response_id,
            temperature: 0.2,
            max_tokens: 1200
          )
        end

        def anthropic_call(provider:, system_prompt:)
          tools = Assistant::Tools::ToolSchemaAdapter.new(allowed_tools).for_anthropic
          messages = build_provider_messages(max_messages: 20)

          provider.run(
            nil,
            messages: messages,
            tools: tools,
            system_message: system_prompt,
            temperature: 0.2,
            max_tokens: 1200
          )
        end

        def build_provider_messages(max_messages:)
          # Provider-native conversational history for chat APIs.
          # Includes the current user message if it is already persisted to the thread.
          if thread.nil?
            return [ { role: "user", content: question } ]
          end

          msgs = thread.messages.chronological.to_a.last(max_messages)

          msgs
            .select { |m| m.role.in?(%w[user assistant]) }
            .reject { |m| m.role == "assistant" && (m.metadata["pending_tool_followup"] == true || m.metadata[:pending_tool_followup] == true) }
            .reject { |m| m.role == "assistant" && (m.metadata["followup_for_assistant_message_id"].present? || m.metadata[:followup_for_assistant_message_id].present?) }
            .map { |m| { role: m.role, content: m.content.to_s } }
        end

        def last_openai_response_id
          return nil if thread.nil?

          turns = thread.turns.order(created_at: :desc).where(provider_name: "openai").limit(25)
          eligible = turns.find do |t|
            state = t.provider_state || {}
            awaiting = state["awaiting_tool_outputs"]
            awaiting = state[:awaiting_tool_outputs] if awaiting.nil?
            awaiting != true
          end

          state = eligible&.provider_state || {}
          state["response_id"] || state[:response_id]
        end

        def build_conversation_history_for_legacy_prompt
          return [] if thread.nil?

          messages = thread.messages.chronological.to_a
          if messages.last&.role == "user" && messages.last&.content&.strip == question.strip
            messages = messages[0..-2]
          end

          messages.map do |msg|
            { role: msg.role, content: msg.content }
          end
        end

        def normalize_tool_call(tc, provider:)
          h = tc.is_a?(Hash) ? tc : {}
          tool_key = h[:tool_key] || h["tool_key"] || h[:name] || h["name"]
          args = h[:args] || h["args"] || h[:input] || h["input"] || {}
          tool_call_id = h[:id] || h["id"] || h[:call_id] || h["call_id"]
          return nil if tool_key.blank?

          {
            tool_key: tool_key.to_s,
            args: args.is_a?(Hash) ? args : {},
            provider_name: provider.to_s,
            provider_tool_call_id: tool_call_id.to_s.presence
          }.compact
        end

        def extract_provider_state(provider:, result:)
          case provider.to_s.downcase
          when "openai"
            { response_id: result[:response_id] || result["response_id"] }.compact
          when "anthropic"
            { message_id: result[:message_id] || result["message_id"] }.compact
          else
            {}
          end
        end

        def build_request_for_log(provider_name:, system_prompt:)
          payload = {
            provider: provider_name,
            system: system_prompt.to_s,
            messages: build_provider_messages(max_messages: 20),
            tools_count: allowed_tools.size
          }
          payload.to_json
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
