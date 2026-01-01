# frozen_string_literal: true

module Assistant
  module Chat
    module Components
      # Continues a tool-using turn by sending tool results back to the LLM using the
      # provider-native protocol, then (optionally) executing additional read-only
      # tools requested by the model up to a bounded iteration limit.
      class ToolFollowupResponder
        MAX_ITERATIONS = 3

        def initialize(user:, thread:, originating_assistant_message:)
          @user = user
          @thread = thread
          @originating_assistant_message = originating_assistant_message
        end

        # @return [Hash] { answer:, tool_executions: }
        def call
          turn = Assistant::Turn.find_by(thread: thread, assistant_message: originating_assistant_message)
          provider_name = (turn&.provider_name || originating_assistant_message.metadata["provider"] || originating_assistant_message.metadata[:provider]).to_s
          provider_state = turn&.provider_state || {}

          allowed_tools = Assistant::ToolPolicy.new(user: user, thread: thread, page_context: {}).allowed_tools

          tool_executions = Assistant::ToolExecution.where(thread: thread, assistant_message: originating_assistant_message).order(created_at: :asc)
          results = tool_executions.map { |te| tool_result_for(te) }.compact

          case provider_name.downcase
          when "openai"
            openai_followup(
              turn: turn,
              provider_state: provider_state,
              allowed_tools: allowed_tools,
              tool_results: results
            )
          when "anthropic"
            anthropic_followup(
              allowed_tools: allowed_tools,
              tool_results: results
            )
          else
            { answer: "Sorry — tool follow-up is not supported for provider: #{provider_name}.", tool_executions: [] }
          end
        end

        private

        attr_reader :user, :thread, :originating_assistant_message

        def openai_followup(turn:, provider_state:, allowed_tools:, tool_results:)
          previous_response_id = provider_state["response_id"] || provider_state[:response_id]
          if previous_response_id.blank?
            return { answer: "Sorry — I couldn't continue the tool-assisted response (missing provider state).", tool_executions: [] }
          end

          provider = LlmProviders::OpenaiProvider.new
          tools = Assistant::Tools::ToolSchemaAdapter.new(allowed_tools).for_openai
          tool_outputs = tool_results.map { |tr| { call_id: tr[:provider_tool_call_id], output: tr.to_json } }

          iterations = 0
          created = []

          loop do
            iterations += 1
            break if iterations > MAX_ITERATIONS

            logger = Ai::ApiLoggerService.new(
              operation_type: :assistant_tool_call,
              loggable: user,
              provider: provider.provider_name,
              model: provider.model_name,
              llm_prompt: Ai::AssistantSystemPrompt.active_prompt
            )

            result = logger.record(prompt: { previous_response_id: previous_response_id, tool_outputs: tool_outputs }.to_json) do
              provider.run(
                nil,
                # Provide a minimal message list so OpenAI input is always valid.
                messages: [ { role: "user", content: "" } ],
                tools: tools,
                previous_response_id: previous_response_id,
                tool_outputs: tool_outputs,
                temperature: 0.2,
                max_tokens: 1200
              )
            end

            break if result[:error].present?

            if result[:response_id].present?
              previous_response_id = result[:response_id]
              persist_openai_response_id!(turn: turn, response_id: previous_response_id)
            end

            tool_calls = Array(result[:tool_calls])
            if tool_calls.any? && iterations < MAX_ITERATIONS
              created += create_and_execute_followup_tools(tool_calls, provider_name: provider.provider_name)
              tool_outputs = created.last(tool_calls.length).map { |te|
                { call_id: te.provider_tool_call_id, output: tool_result_for(te).to_json }
              }
              next
            end

            answer = result[:content].to_s
            answer = "Done." if answer.strip.blank?
            return { answer: answer, tool_executions: created }
          end

          { answer: "Sorry — I couldn’t finish the tool follow-up.", tool_executions: created }
        end

        def persist_openai_response_id!(turn:, response_id:)
          return if turn.nil? || response_id.blank?

          turn.update!(provider_name: "openai", provider_state: (turn.provider_state || {}).merge("response_id" => response_id, "awaiting_tool_outputs" => false))
          originating_assistant_message.update!(
            metadata: originating_assistant_message.metadata.merge(
              "provider_state" => (originating_assistant_message.metadata["provider_state"] || {}).merge("response_id" => response_id),
              "awaiting_tool_outputs" => false
            )
          )
        rescue StandardError
          # best-effort only
        end

        def anthropic_followup(allowed_tools:, tool_results:)
          provider = LlmProviders::AnthropicProvider.new
          system_prompt = Ai::AssistantSystemPrompt.active_prompt&.prompt_template || Ai::AssistantSystemPrompt.default_prompt_template
          tools = Assistant::Tools::ToolSchemaAdapter.new(allowed_tools).for_anthropic

          messages = build_anthropic_history_messages
          created = []

          tool_result_blocks = tool_results.map do |tr|
            {
              type: "tool_result",
              tool_use_id: tr[:provider_tool_call_id],
              content: tr.to_json,
              is_error: tr[:success] == false
            }.compact
          end

          iterations = 0
          loop do
            iterations += 1
            break if iterations > MAX_ITERATIONS

            logger = Ai::ApiLoggerService.new(
              operation_type: :assistant_tool_call,
              loggable: user,
              provider: provider.provider_name,
              model: provider.model_name,
              llm_prompt: Ai::AssistantSystemPrompt.active_prompt
            )

            result = logger.record(prompt: { messages_count: messages.length, tool_results_count: tool_result_blocks.length }.to_json) do
              provider.run(
                nil,
                messages: messages + [ { role: "user", content: tool_result_blocks } ],
                tools: tools,
                system_message: system_prompt,
                temperature: 0.2,
                max_tokens: 1200
              )
            end

            break if result[:error].present?

            # Add the full assistant blocks back to history so tool_result blocks have context.
            if result[:content_blocks].present?
              messages << { role: "assistant", content: result[:content_blocks] }
            else
              messages << { role: "assistant", content: result[:content].to_s }
            end

            tool_calls = Array(result[:tool_calls])
            if tool_calls.any? && iterations < MAX_ITERATIONS
              created += create_and_execute_followup_tools(tool_calls, provider_name: provider.provider_name)
              tool_result_blocks = created.last(tool_calls.length).map { |te|
                tr = tool_result_for(te)
                {
                  type: "tool_result",
                  tool_use_id: te.provider_tool_call_id,
                  content: tr.to_json,
                  is_error: tr[:success] == false
                }.compact
              }
              next
            end

            answer = result[:content].to_s
            answer = "Done." if answer.strip.blank?
            return { answer: answer, tool_executions: created }
          end

          { answer: "Sorry — I couldn’t finish the tool follow-up.", tool_executions: created }
        end

        def build_anthropic_history_messages
          # Anthropic is stateless: send full conversational history each time.
          # If an assistant message was originally created from Anthropic, prefer the stored content blocks.
          thread.messages.chronological.map do |m|
            next unless m.role.in?(%w[user assistant])
            next if m.role == "assistant" && (m.metadata["pending_tool_followup"] == true || m.metadata[:pending_tool_followup] == true)
            next if m.role == "assistant" && (m.metadata["followup_for_assistant_message_id"].present? || m.metadata[:followup_for_assistant_message_id].present?)

            if m.role == "assistant" && m.metadata["provider"] == "anthropic" && m.metadata["provider_content_blocks"].is_a?(Array)
              { role: "assistant", content: m.metadata["provider_content_blocks"] }
            else
              { role: m.role, content: m.content.to_s }
            end
          end.compact
        end

        def create_and_execute_followup_tools(tool_calls, provider_name:)
          created = []

          Array(tool_calls).each do |tc|
            tool_key = tc[:tool_key] || tc["tool_key"] || tc[:name] || tc["name"]
            args = tc[:args] || tc["args"] || tc[:input] || tc["input"] || {}
            provider_tool_call_id = tc[:id] || tc["id"] || tc[:call_id] || tc["call_id"]

            tool = Assistant::Tool.find_by(tool_key: tool_key.to_s)
            next unless tool&.enabled?

            te = Assistant::ToolExecution.create!(
              thread: thread,
              assistant_message: originating_assistant_message,
              tool_key: tool.tool_key,
              args: args.is_a?(Hash) ? args : {},
              status: "proposed",
              trace_id: originating_assistant_message.metadata["trace_id"] || originating_assistant_message.metadata[:trace_id] || SecureRandom.uuid,
              requires_confirmation: tool.requires_confirmation || tool.risk_level != "read_only",
              idempotency_key: SecureRandom.uuid,
              provider_name: provider_name,
              provider_tool_call_id: provider_tool_call_id.to_s.presence
            )

            created << te

            next if te.requires_confirmation

            Assistant::Tools::Runner.new(user: user, tool_execution: te).call
          end

          created
        end

        def tool_result_for(tool_execution)
          return nil if tool_execution.provider_tool_call_id.blank?
          return nil unless tool_execution.status.in?(%w[success error])

          result = {
            provider_tool_call_id: tool_execution.provider_tool_call_id,
            tool_key: tool_execution.tool_key,
            success: tool_execution.status == "success",
            data: tool_execution.result,
            error: tool_execution.error
          }.compact

          contract = Assistant::Contracts::ToolResultContract.call(result)
          if contract.success?
            result
          else
            Rails.logger.warn("[ToolFollowupResponder] Invalid tool_result dropped: errors=#{contract.errors.to_h.inspect} tool_result=#{result.inspect}")
            nil
          end
        end
      end
    end
  end
end
