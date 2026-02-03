# frozen_string_literal: true

require "test_helper"

module Assistant
  module Chat
    class ToolResultMessagePersisterTest < ActiveSupport::TestCase
      test "persists tool result as role=tool chat message (idempotent)" do
        user = create(:user, :with_applications, name: "Test User")
        thread = Assistant::ChatThread.create!(user: user, status: "open", title: nil, last_activity_at: Time.current)

        assistant_message = thread.messages.create!(role: "assistant", content: "Placeholder", metadata: { provider: "anthropic" })

        tool_execution = thread.tool_executions.create!(
          assistant_message: assistant_message,
          tool_key: "list_interview_applications",
          args: { "status" => "active" },
          status: "success",
          trace_id: SecureRandom.uuid,
          requires_confirmation: false,
          idempotency_key: SecureRandom.uuid,
          provider_name: "anthropic",
          provider_tool_call_id: "toolu_test",
          result: { "count" => 1, "applications" => [] }
        )

        persister = Assistant::Chat::ToolResultMessagePersister.new(tool_execution: tool_execution)
        msg1 = persister.call
        msg2 = persister.call

        assert msg1.present?
        assert_equal "tool", msg1.role
        assert_equal msg1.id, msg2.id

        meta = msg1.metadata || {}
        assert_equal tool_execution.id, meta["tool_execution_id"] || meta[:tool_execution_id]
        assert_equal "toolu_test", meta["provider_tool_call_id"] || meta[:provider_tool_call_id]
        assert_equal assistant_message.id, meta["originating_assistant_message_id"] || meta[:originating_assistant_message_id]
      end
    end
  end
end
