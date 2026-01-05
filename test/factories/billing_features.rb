# frozen_string_literal: true

FactoryBot.define do
  factory :billing_feature, class: "Billing::Feature" do
    sequence(:key) { |n| "feature_#{n}" }
    sequence(:name) { |n| "Feature #{n}" }
    description { "Feature description" }
    kind { "boolean" }
    unit { nil }
    metadata { {} }

    trait :quota do
      kind { "quota" }
      unit { "count" }
    end
  end
end


