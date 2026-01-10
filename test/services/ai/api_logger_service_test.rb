# frozen_string_literal: true

require "test_helper"

class Ai::ApiLoggerServiceTest < ActiveSupport::TestCase
  test "record_result stores provider-native request/response payloads" do
    user = create(:user)

    logger = Ai::ApiLoggerService.new(
      operation_type: :assistant_chat,
      loggable: user,
      provider: "openai",
      model: "gpt-4o-mini",
      llm_prompt: nil
    )

    log = logger.record_result(
      {
        content: "Hello",
        input_tokens: 12,
        output_tokens: 34,
        provider_request: {
          model: "gpt-4o-mini",
          input: [ { role: "user", content: "Hi" } ]
        },
        provider_response: {
          "id" => "resp_123",
          "output" => []
        },
        http_status: 200,
        response_headers: { "x-request-id" => "req_abc" },
        provider_endpoint: "https://api.openai.com"
      },
      latency_ms: 25,
      prompt: "PROMPT",
      content_size: 6
    )

    log.reload

    assert_equal "PROMPT", log.request_payload["prompt"]
    assert_equal "gpt-4o-mini", log.request_payload.dig("provider_request", "model")

    assert_equal "resp_123", log.response_payload.dig("provider_response", "id")
    assert_equal 200, log.response_payload["http_status"]
    assert_equal "req_abc", log.response_payload.dig("response_headers", "x-request-id")
    assert_equal "https://api.openai.com", log.response_payload["provider_endpoint"]
  end

  test "record updates request_payload after yield to include provider_request" do
    user = create(:user)

    logger = Ai::ApiLoggerService.new(
      operation_type: :assistant_chat,
      loggable: user,
      provider: "openai",
      model: "gpt-4o-mini",
      llm_prompt: nil
    )

    result = logger.record(prompt: "PROMPT", content_size: 6) do
      {
        content: "Hello",
        input_tokens: 12,
        output_tokens: 34,
        provider_request: { model: "gpt-4o-mini" },
        provider_response: { "id" => "resp_999" }
      }
    end

    log = Ai::LlmApiLog.find(result.fetch(:llm_api_log_id))
    assert_equal "gpt-4o-mini", log.request_payload.dig("provider_request", "model")
    assert_equal "resp_999", log.response_payload.dig("provider_response", "id")
  end

  test "record captures exception response payload on raise" do
    user = create(:user)

    logger = Ai::ApiLoggerService.new(
      operation_type: :assistant_chat,
      loggable: user,
      provider: "openai",
      model: "gpt-4o-mini",
      llm_prompt: nil
    )

    error = assert_raises(RuntimeError) do
      logger.record(prompt: "PROMPT", content_size: 6) do
        raise RuntimeError, "boom"
      end
    end
    assert_equal "boom", error.message

    log = logger.log
    log.reload

    assert_equal "RuntimeError", log.response_payload["exception_class"]
    assert_equal "boom", log.response_payload["exception_message"]
  end
end
