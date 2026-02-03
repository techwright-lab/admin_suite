# frozen_string_literal: true

require "test_helper"

module Assistant
  module Chat
    class ToolFollowupResponderAnthropicHistoryTest < ActiveSupport::TestCase
      test "anthropic history inserts tool_result user message after prior tool_use blocks" do
        user = create(:user, :with_applications, name: "Test User")
        thread = Assistant::ChatThread.create!(user: user, status: "open", title: nil, last_activity_at: Time.current)

        prior_assistant = thread.messages.create!(
          role: "assistant",
          content: "Working on it",
          metadata: {
            provider: "anthropic",
            provider_content_blocks: [
              { "type" => "tool_use", "id" => "toolu_prior", "name" => "list_interview_applications", "input" => { "status" => "active" } }
            ]
          }
        )

        thread.tool_executions.create!(
          assistant_message: prior_assistant,
          tool_key: "list_interview_applications",
          args: { "status" => "active" },
          status: "success",
          trace_id: SecureRandom.uuid,
          requires_confirmation: false,
          idempotency_key: SecureRandom.uuid,
          provider_name: "anthropic",
          provider_tool_call_id: "toolu_prior",
          result: { "count" => 1, "applications" => [] }
        )

        originating = thread.messages.create!(
          role: "assistant",
          content: "Later message",
          metadata: { provider: "anthropic", pending_tool_followup: false, provider_content_blocks: [ { "type" => "text", "text" => "Hi" } ] }
        )

        builder = Assistant::Providers::Anthropic::MessageBuilder.new(
          thread: thread,
          question: "",
          system_prompt: "system",
          allowed_tools: [],
          media: []
        )
        history = builder.build_history_messages(exclude_tool_results_for_assistant_message_id: originating.id)

        idx = history.index { |m| m[:role] == "assistant" && m[:content].is_a?(Array) && m[:content].any? { |b| b["type"] == "tool_use" && b["id"] == "toolu_prior" } }
        assert idx.present?, "Expected to find prior assistant tool_use message in history"

        next_msg = history[idx + 1]
        assert_equal "user", next_msg[:role]
        assert next_msg[:content].is_a?(Array)
        tool_result = next_msg[:content].find { |b| b[:type] == "tool_result" || b["type"] == "tool_result" }
        assert tool_result.present?
        assert_equal "toolu_prior", (tool_result[:tool_use_id] || tool_result["tool_use_id"])
      end
    end
  end
end
