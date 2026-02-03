# frozen_string_literal: true

module Assistant
  module Providers
    module Openai
      # Builds OpenAI Responses API request options for assistant chat.
      class MessageBuilder
        MAX_HISTORY_MESSAGES = 20

        def initialize(thread:, question:, system_prompt:, allowed_tools:, media: [])
          @thread = thread
          @question = question.to_s
          @system_prompt = system_prompt.to_s
          @allowed_tools = Array(allowed_tools)
          @media = Array(media).compact
        end

        # @return [Hash] options hash for LlmProviders::OpenaiProvider#run
        def build_chat_options
          tools = Assistant::Tools::ToolSchemaAdapter.new(allowed_tools).for_openai
          previous_response_id = last_openai_response_id

          messages =
            if previous_response_id.present?
              [ { role: "user", content: question } ]
            else
              history = build_history_messages
              [ { role: "system", content: system_prompt } ] + history + [ { role: "user", content: question } ]
            end

          opts = {
            messages: messages,
            tools: tools,
            previous_response_id: previous_response_id,
            temperature: 0.2,
            max_tokens: 1200
          }
          opts[:media] = media if media.present?
          opts
        end

        # @return [Hash]
        def build_log_payload
          {
            provider: "openai",
            system: system_prompt.to_s,
            previous_response_id: last_openai_response_id,
            messages: build_history_messages + [ { role: "user", content: question } ],
            tools_count: allowed_tools.size
          }
        end

        private

        attr_reader :thread, :question, :system_prompt, :allowed_tools, :media

        def build_history_messages
          return [] if thread.nil?

          msgs = thread.messages.chronological.to_a.last(MAX_HISTORY_MESSAGES)
          msgs
            .select { |m| m.role.in?(%w[user assistant]) }
            .reject { |m| m.role == "assistant" && (m.metadata["pending_tool_followup"] == true || m.metadata[:pending_tool_followup] == true) }
            .reject { |m| m.role == "assistant" && (m.metadata["followup_for_assistant_message_id"].present? || m.metadata[:followup_for_assistant_message_id].present?) }
            .map { |m| { role: m.role, content: m.content.to_s } }
        end

        # Mirrors prior behavior in LlmResponder: reuse last response_id that is not awaiting tool outputs.
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
      end
    end
  end
end
