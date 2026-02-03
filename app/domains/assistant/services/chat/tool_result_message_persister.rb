# frozen_string_literal: true

module Assistant
  module Chat
    # Persists a tool execution outcome as a canonical tool-result chat message.
    #
    # This is used to build provider-native histories reliably (especially for Anthropic,
    # which requires tool_use blocks to be followed by tool_result blocks).
    class ToolResultMessagePersister
      # @param tool_execution [Assistant::ToolExecution]
      def initialize(tool_execution:)
        @tool_execution = tool_execution
      end

      # @return [Assistant::ChatMessage, nil]
      def call
        return nil if tool_execution.nil?
        return nil unless tool_execution.status.in?(%w[success error])

        msg = find_or_initialize_message

        msg.role = "tool"
        msg.content = build_content
        msg.metadata = build_metadata
        msg.save!

        msg
      rescue StandardError
        nil
      end

      private

      attr_reader :tool_execution

      def find_or_initialize_message
        Assistant::ChatMessage
          .where(thread: tool_execution.thread, role: "tool")
          .where("metadata ->> 'tool_execution_id' = ?", tool_execution.id.to_s)
          .first || tool_execution.thread.messages.build(role: "tool")
      end

      def build_content
        status = tool_execution.status == "success" ? "success" : "error"
        "Tool result (#{tool_execution.tool_key}): #{status}"
      end

      def build_metadata
        {
          tool_execution_id: tool_execution.id,
          trace_id: tool_execution.trace_id,
          provider_name: tool_execution.provider_name,
          provider_tool_call_id: tool_execution.provider_tool_call_id,
          tool_key: tool_execution.tool_key,
          success: tool_execution.status == "success",
          data: tool_execution.result,
          error: tool_execution.error,
          originating_assistant_message_id: tool_execution.assistant_message_id
        }.compact
      end
    end
  end
end
