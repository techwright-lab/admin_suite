# frozen_string_literal: true

require "test_helper"

module Assistant
  module Providers
    class OpenaiMessageBuilderTest < ActiveSupport::TestCase
      test "builder uses previous_response_id when available" do
        user = create(:user, :with_applications, name: "Test User")
        thread = Assistant::ChatThread.create!(user: user, status: "open", title: nil, last_activity_at: Time.current)

        um = thread.messages.create!(role: "user", content: "hi", metadata: {})
        am = thread.messages.create!(role: "assistant", content: "hello", metadata: {})
        thread.turns.create!(
          user_message: um,
          assistant_message: am,
          trace_id: SecureRandom.uuid,
          status: "success",
          provider_name: "openai",
          provider_state: { "response_id" => "resp_123", "awaiting_tool_outputs" => false },
          llm_api_log: create(:llm_api_log, :openai)
        )

        builder = Assistant::Providers::Openai::MessageBuilder.new(
          thread: thread,
          question: "next",
          system_prompt: "system",
          allowed_tools: [],
          media: []
        )
        opts = builder.build_chat_options

        assert_equal "resp_123", opts[:previous_response_id]
        assert_equal [ { role: "user", content: "next" } ], opts[:messages]
      end
    end
  end
end
