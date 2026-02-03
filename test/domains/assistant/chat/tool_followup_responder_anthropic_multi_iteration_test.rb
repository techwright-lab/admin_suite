# frozen_string_literal: true

require "test_helper"

module Assistant
  module Chat
    class ToolFollowupResponderAnthropicMultiIterationTest < ActiveSupport::TestCase
      test "anthropic followup preserves tool_result adjacency across multiple tool batches" do
        user = create(:user, :with_applications, name: "Test User")
        thread = Assistant::ChatThread.create!(user: user, status: "open", title: nil, last_activity_at: Time.current)

        originating = thread.messages.create!(
          role: "assistant",
          content: "Working on it",
          metadata: {
            provider: "anthropic",
            pending_tool_followup: true,
            provider_content_blocks: [
              { "type" => "tool_use", "id" => "toolu_origin", "name" => "list_interview_applications", "input" => {} }
            ]
          }
        )

        responder = Assistant::Chat::Components::ToolFollowupResponder.new(
          user: user,
          thread: thread,
          originating_assistant_message: originating
        )

        # Fake tool executions for follow-up tools (OpenStruct is enough for tool_result_for)
        te_a = OpenStruct.new(provider_tool_call_id: "toolu_a", tool_key: "get_interview_application", status: "success", result: { "ok" => true }, error: nil)
        te_b = OpenStruct.new(provider_tool_call_id: "toolu_b", tool_key: "get_interview_feedback", status: "success", result: { "ok" => true }, error: nil)

        # Capture the messages payload passed to provider.run on each iteration.
        seen = []
        fake_provider = Object.new
        fake_provider.define_singleton_method(:provider_name) { "anthropic" }
        fake_provider.define_singleton_method(:model_name) { "fake" }
        fake_provider.define_singleton_method(:run) do |_prompt, **opts|
          seen << opts[:messages]
          idx = seen.length

          case idx
          when 1
            {
              content: "",
              content_blocks: [
                { "type" => "text", "text" => "OK" },
                { "type" => "tool_use", "id" => "toolu_a", "name" => "get_interview_application", "input" => {} }
              ],
              tool_calls: [ { id: "toolu_a", tool_key: "get_interview_application", args: {} } ],
              error: nil,
              llm_api_log_id: FactoryBot.create(:llm_api_log).id,
              latency_ms: 1
            }
          when 2
            {
              content: "",
              content_blocks: [
                { "type" => "text", "text" => "More" },
                { "type" => "tool_use", "id" => "toolu_b", "name" => "get_interview_feedback", "input" => {} }
              ],
              tool_calls: [ { id: "toolu_b", tool_key: "get_interview_feedback", args: {} } ],
              error: nil,
              llm_api_log_id: FactoryBot.create(:llm_api_log).id,
              latency_ms: 1
            }
          else
            {
              content: "Done",
              content_blocks: [ { "type" => "text", "text" => "Done" } ],
              tool_calls: [],
              error: nil,
              llm_api_log_id: FactoryBot.create(:llm_api_log).id,
              latency_ms: 1
            }
          end
        end

        fake_logger = Object.new
        fake_logger.define_singleton_method(:record) { |prompt:, **_kw, &blk| blk.call }

        # Rails' test stack here doesn't expose Module#stub reliably, so do a manual, scoped stub.
        LlmProviders::AnthropicProvider.singleton_class.alias_method(:__orig_new, :new)
        Ai::ApiLoggerService.singleton_class.alias_method(:__orig_new, :new)
        LlmProviders::AnthropicProvider.define_singleton_method(:new) { fake_provider }
        Ai::ApiLoggerService.define_singleton_method(:new) { |**_kwargs| fake_logger }

        begin
          responder.define_singleton_method(:create_and_execute_followup_tools) do |tool_calls, provider_name:|
            ids = Array(tool_calls).map { |tc| tc[:id] || tc["id"] }
            if ids.include?("toolu_a")
              [ te_a ]
            elsif ids.include?("toolu_b")
              [ te_b ]
            else
              []
            end
          end

          responder.send(
            :anthropic_followup,
            allowed_tools: [],
            tool_results: [ { provider_tool_call_id: "toolu_origin", tool_key: "list_interview_applications", success: true, data: {} } ]
          )
        ensure
          LlmProviders::AnthropicProvider.singleton_class.alias_method(:new, :__orig_new)
          LlmProviders::AnthropicProvider.singleton_class.remove_method(:__orig_new)
          Ai::ApiLoggerService.singleton_class.alias_method(:new, :__orig_new)
          Ai::ApiLoggerService.singleton_class.remove_method(:__orig_new)
        end

        # Third call should include:
        # assistant(toolu_a) -> user(tool_result for toolu_a) -> assistant(toolu_b) -> user(tool_result for toolu_b)
        third = seen[2]
        assert third.present?, "Expected a third provider call"

        # Find the assistant toolu_a message and ensure next is user tool_result for toolu_a
        idx_a = third.index do |m|
          m[:role] == "assistant" &&
            m[:content].is_a?(Array) &&
            m[:content].any? { |b| (b["type"] || b[:type]).to_s == "tool_use" && (b["id"] || b[:id]) == "toolu_a" }
        end
        assert idx_a, "Expected assistant tool_use toolu_a in third call"

        next_after_a = third[idx_a + 1]
        assert_equal "user", next_after_a[:role]
        ids = Array(next_after_a[:content]).filter_map { |b| (b["type"] || b[:type]).to_s == "tool_result" ? (b["tool_use_id"] || b[:tool_use_id]) : nil }
        assert_includes ids, "toolu_a"
      end
    end
  end
end
