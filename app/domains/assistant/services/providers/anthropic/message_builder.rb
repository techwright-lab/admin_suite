# frozen_string_literal: true

module Assistant
  module Providers
    module Anthropic
      # Builds Anthropic Messages API request options for assistant chat and follow-ups.
      #
      # Key rule: every assistant tool_use block must be immediately followed by a user message
      # with tool_result blocks for those tool_use ids.
      class MessageBuilder
        MAX_HISTORY_MESSAGES = 40

        def initialize(thread:, question:, system_prompt:, allowed_tools:, media: [])
          @thread = thread
          @question = question.to_s
          @system_prompt = system_prompt.to_s
          @allowed_tools = Array(allowed_tools)
          @media = Array(media).compact
        end

        # @return [Hash] options hash for LlmProviders::AnthropicProvider#run
        def build_chat_options
          tools = Assistant::Tools::ToolSchemaAdapter.new(allowed_tools).for_anthropic
          messages = build_history_messages + [ { role: "user", content: question } ]

          opts = {
            messages: messages,
            tools: tools,
            system_message: system_prompt,
            temperature: 0.2,
            max_tokens: 1200
          }
          opts[:media] = media if media.present?
          opts
        end

        # @return [Hash]
        def build_log_payload
          {
            provider: "anthropic",
            system: system_prompt.to_s,
            messages_count: build_history_messages.length + 1,
            tools_count: allowed_tools.size
          }
        end

        # Builds conversational history including persisted tool results.
        #
        # @param exclude_tool_results_for_assistant_message_id [Integer, nil]
        # @param include_pending_assistant_message_id [Integer, nil] include even if pending_tool_followup
        # @return [Array<Hash>]
        def build_history_messages(exclude_tool_results_for_assistant_message_id: nil, include_pending_assistant_message_id: nil)
          return [] if thread.nil?

          msgs = thread.messages.chronological.to_a.last(MAX_HISTORY_MESSAGES)
          out = []

          msgs.each do |m|
            next unless m.role.in?(%w[user assistant])
            is_included_pending = include_pending_assistant_message_id.to_i == m.id
            next if !is_included_pending && m.role == "assistant" && (m.metadata["pending_tool_followup"] == true || m.metadata[:pending_tool_followup] == true)
            next if m.role == "assistant" && (m.metadata["followup_for_assistant_message_id"].present? || m.metadata[:followup_for_assistant_message_id].present?)

            if m.role == "assistant" && m.metadata["provider"] == "anthropic" && m.metadata["provider_content_blocks"].is_a?(Array)
              blocks = Array(m.metadata["provider_content_blocks"])
              out << { role: "assistant", content: blocks }

              tool_use_ids = extract_tool_use_ids(blocks)
              next if tool_use_ids.empty?
              next if exclude_tool_results_for_assistant_message_id.to_i == m.id

              tool_result_blocks = build_tool_result_blocks_for_assistant_message(m, tool_use_ids)
              out << { role: "user", content: tool_result_blocks } if tool_result_blocks.any?
            else
              out << { role: m.role, content: m.content.to_s }
            end
          end

          out
        end

        private

        attr_reader :thread, :question, :system_prompt, :allowed_tools, :media

        def extract_tool_use_ids(blocks)
          Array(blocks).filter_map do |b|
            next unless (b["type"] || b[:type]).to_s == "tool_use"
            (b["id"] || b[:id]).to_s.presence
          end
        end

        def build_tool_result_blocks_for_assistant_message(assistant_message, tool_use_ids)
          tool_messages = Assistant::ChatMessage
            .where(thread: assistant_message.thread, role: "tool")
            .where("metadata ->> 'originating_assistant_message_id' = ?", assistant_message.id.to_s)
            .where("metadata ->> 'provider_tool_call_id' IN (?)", tool_use_ids)
            .order(created_at: :asc)
            .to_a

          by_call_id = tool_messages.index_by { |m| m.metadata["provider_tool_call_id"] || m.metadata[:provider_tool_call_id] }

          tool_use_ids.map do |id|
            tm = by_call_id[id]
            payload =
              if tm
                meta = tm.metadata || {}
                {
                  provider_tool_call_id: meta["provider_tool_call_id"] || meta[:provider_tool_call_id],
                  tool_key: meta["tool_key"] || meta[:tool_key] || "unknown",
                  success: meta["success"] == true || meta[:success] == true,
                  data: meta["data"] || meta[:data],
                  error: meta["error"] || meta[:error]
                }.compact
              else
                fallback_tool_execution_payload(assistant_message, id)
              end

            {
              type: "tool_result",
              tool_use_id: id,
              content: payload.to_json,
              is_error: payload[:success] == false
            }.compact
          end
        end

        def fallback_tool_execution_payload(assistant_message, tool_use_id)
          te = Assistant::ToolExecution.where(thread: assistant_message.thread, assistant_message: assistant_message, provider_tool_call_id: tool_use_id).order(created_at: :desc).first
          if te && te.status.in?(%w[success error])
            {
              provider_tool_call_id: te.provider_tool_call_id,
              tool_key: te.tool_key,
              success: te.status == "success",
              data: te.result,
              error: te.error
            }.compact
          else
            { provider_tool_call_id: tool_use_id, tool_key: "unknown", success: false, error: "Tool result unavailable" }
          end
        end
      end
    end
  end
end
