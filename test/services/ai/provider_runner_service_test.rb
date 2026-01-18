# frozen_string_literal: true

require "test_helper"

class Ai::ProviderRunnerServiceTest < ActiveSupport::TestCase
  class FakeProvider
    attr_reader :model_name

    def initialize(model_name:, responses:)
      @model_name = model_name
      @responses = responses
      @calls = 0
    end

    def available?
      true
    end

    def run(_prompt, **_options)
      response = @responses[@calls] || @responses.last
      @calls += 1
      response
    end
  end

  def build_logger(user, provider_name, provider)
    Ai::ApiLoggerService.new(
      operation_type: :assistant_chat,
      loggable: user,
      provider: provider_name,
      model: provider.model_name,
      llm_prompt: nil
    )
  end

  test "runs provider and returns parsed result with log" do
    user = create(:user)
    provider = FakeProvider.new(
      model_name: "gpt-4o-mini",
      responses: [
        {
          content: "{\"ok\":true}",
          input_tokens: 12,
          output_tokens: 34,
          provider_request: { model: "gpt-4o-mini" },
          provider_response: { "id" => "resp_123" }
        }
      ]
    )

    runner = Ai::ProviderRunnerService.new(
      provider_chain: [ "openai" ],
      prompt: "PROMPT",
      content_size: 6,
      system_message: "SYS",
      provider_for: ->(_name) { provider },
      logger_builder: ->(name, prov) { build_logger(user, name, prov) }
    )

    result = runner.run do |_response|
      parsed = { "ok" => true }
      log_data = { custom: "value" }
      [ parsed, log_data, true ]
    end

    assert result[:success]
    log = Ai::LlmApiLog.find(result[:llm_api_log_id])
    assert_equal "openai", log.provider
    assert_equal "gpt-4o-mini", log.model
    assert_equal "gpt-4o-mini", log.request_payload.dig("provider_request", "model")
    assert_includes log.response_payload["raw_response"], "{\"ok\":true}"
  end

  test "continues after rate limit and succeeds on next provider" do
    user = create(:user)
    rate_limited = FakeProvider.new(
      model_name: "gpt-4o-mini",
      responses: [ { rate_limit: true } ]
    )
    success = FakeProvider.new(
      model_name: "gpt-4o-mini",
      responses: [ { content: "{\"ok\":true}" } ]
    )

    providers = { "openai" => rate_limited, "anthropic" => success }
    called = []

    runner = Ai::ProviderRunnerService.new(
      provider_chain: [ "openai", "anthropic" ],
      prompt: "PROMPT",
      content_size: 6,
      provider_for: ->(name) { providers[name] },
      logger_builder: ->(name, prov) { build_logger(user, name, prov) },
      on_rate_limit: ->(_response, provider_name, _logger) { called << provider_name }
    )

    assert_difference "Ai::LlmApiLog.count", 2 do
      result = runner.run { |response| [ { "ok" => true }, {}, response[:content].present? ] }
      assert result[:success]
      assert_equal "anthropic", result[:provider]
    end

    assert_equal [ "openai" ], called
  end

  test "skips low confidence results and falls back" do
    user = create(:user)
    low_conf = FakeProvider.new(
      model_name: "gpt-4o-mini",
      responses: [ { content: "{\"confidence\":0.2}" } ]
    )
    high_conf = FakeProvider.new(
      model_name: "gpt-4o-mini",
      responses: [ { content: "{\"confidence\":0.9}" } ]
    )

    providers = { "openai" => low_conf, "anthropic" => high_conf }

    runner = Ai::ProviderRunnerService.new(
      provider_chain: [ "openai", "anthropic" ],
      prompt: "PROMPT",
      content_size: 6,
      provider_for: ->(name) { providers[name] },
      logger_builder: ->(name, prov) { build_logger(user, name, prov) }
    )

    result = runner.run do |response|
      confidence = response[:content].to_s.include?("0.9") ? 0.9 : 0.2
      parsed = { "confidence" => confidence }
      accept = confidence >= 0.5
      [ parsed, {}, accept ]
    end

    assert result[:success]
    assert_equal "anthropic", result[:provider]
  end
end
