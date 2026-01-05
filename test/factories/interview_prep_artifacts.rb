# frozen_string_literal: true

FactoryBot.define do
  factory :interview_prep_artifact do
    association :interview_application
    association :user

    kind { :match_analysis }
    status { :pending }
    inputs_digest { SecureRandom.hex(16) }
    content { {} }
    computed_at { nil }
    error_message { nil }
    provider { nil }
    model { nil }

    trait :computed do
      status { :computed }
      computed_at { Time.current }
      content { { "ok" => true } }
    end

    trait :failed do
      status { :failed }
      computed_at { Time.current }
      error_message { "All providers failed" }
      content { {} }
    end
  end
end
