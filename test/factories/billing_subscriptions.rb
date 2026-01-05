# frozen_string_literal: true

FactoryBot.define do
  factory :billing_subscription, class: "Billing::Subscription" do
    association :user
    association :plan, factory: :billing_plan
    provider { "lemonsqueezy" }
    sequence(:external_subscription_id) { |n| "sub_#{n}" }
    status { "active" }
    current_period_starts_at { 1.day.ago }
    current_period_ends_at { 1.month.from_now }
    trial_ends_at { nil }
    cancel_at_period_end { false }
    cancelled_at { nil }
    metadata { {} }

    trait :trialing do
      status { "trialing" }
      trial_ends_at { 3.days.from_now }
    end
  end
end


