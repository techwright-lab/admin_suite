# frozen_string_literal: true

require "test_helper"

module Assistant
  module Providers
    class AnthropicMessageBuilderTest < ActiveSupport::TestCase
      test "builder inserts tool_result blocks from role=tool messages after tool_use" do
        user = create(:user, :with_applications, name: "Test User")
        thread = Assistant::ChatThread.create!(user: user, status: "open", title: nil, last_activity_at: Time.current)

        assistant = thread.messages.create!(
          role: "assistant",
          content: "Working on it",
          metadata: {
            provider: "anthropic",
            provider_content_blocks: [
              { "type" => "tool_use", "id" => "toolu_1", "name" => "list_interview_applications", "input" => { "status" => "active" } }
            ]
          }
        )

        # Persisted tool result message (new path)
        thread.messages.create!(
          role: "tool",
          content: "Tool result",
          metadata: {
            originating_assistant_message_id: assistant.id,
            provider_tool_call_id: "toolu_1",
            tool_key: "list_interview_applications",
            success: true,
            data: { "count" => 1, "applications" => [] }
          }
        )

        builder = Assistant::Providers::Anthropic::MessageBuilder.new(
          thread: thread,
          question: "hi",
          system_prompt: "system",
          allowed_tools: [],
          media: []
        )

        history = builder.build_history_messages
        idx = history.index { |m| m[:role] == "assistant" && m[:content].is_a?(Array) && m[:content].any? { |b| b["type"] == "tool_use" && b["id"] == "toolu_1" } }
        assert idx.present?

        next_msg = history[idx + 1]
        assert_equal "user", next_msg[:role]
        tool_result = Array(next_msg[:content]).find { |b| (b[:type] || b["type"]) == "tool_result" }
        assert tool_result.present?
        assert_equal "toolu_1", (tool_result[:tool_use_id] || tool_result["tool_use_id"])
      end
    end
  end
end
