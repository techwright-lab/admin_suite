# frozen_string_literal: true

FactoryBot.define do
  factory :llm_api_log, class: "Ai::LlmApiLog" do
    operation_type { "job_extraction" }
    provider { "anthropic" }
    model { "claude-sonnet-4-20250514" }
    status { :success }

    input_tokens { rand(1000..5000) }
    output_tokens { rand(200..1000) }
    latency_ms { rand(1000..5000) }
    confidence_score { rand(0.7..1.0).round(2) }

    request_payload { { prompt: "Test prompt" } }
    response_payload { { content: "Test response" } }

    trait :with_job_listing do
      association :loggable, factory: :job_listing
    end

    trait :with_opportunity do
      association :loggable, factory: :opportunity
    end

    trait :with_user_resume do
      association :loggable, factory: :user_resume
    end

    trait :with_llm_prompt do
      association :llm_prompt, factory: :job_extraction_prompt
    end

    trait :job_extraction do
      operation_type { "job_extraction" }
    end

    trait :email_extraction do
      operation_type { "email_extraction" }
    end

    trait :resume_extraction do
      operation_type { "resume_extraction" }
    end

    trait :success do
      status { :success }
      error_type { nil }
      error_message { nil }
    end

    trait :error do
      status { :error }
      error_type { "unknown" }
      error_message { "Test error message" }
      confidence_score { nil }
    end

    trait :timeout do
      status { :timeout }
      error_type { "timeout" }
      error_message { "Request timed out" }
    end

    trait :rate_limited do
      status { :rate_limited }
      error_type { "rate_limit" }
      error_message { "Rate limit exceeded" }
    end

    trait :openai do
      provider { "openai" }
      model { "gpt-4o" }
    end

    trait :ollama do
      provider { "ollama" }
      model { "llama2" }
    end
  end
end




