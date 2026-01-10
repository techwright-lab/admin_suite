# frozen_string_literal: true

FactoryBot.define do
  factory :domain do
    sequence(:name) { |n| "Domain #{n}" }
    sequence(:description) { |n| "Description for domain #{n}" }

    trait :fintech do
      name { "FinTech" }
      description { "Financial technology" }
    end

    trait :saas do
      name { "SaaS" }
      description { "Software as a Service" }
    end

    trait :ai_ml do
      name { "AI/ML" }
      description { "Artificial Intelligence and Machine Learning" }
    end

    trait :healthcare do
      name { "Healthcare" }
      description { "Healthcare technology" }
    end

    trait :ecommerce do
      name { "E-commerce" }
      description { "Electronic commerce" }
    end
  end
end
