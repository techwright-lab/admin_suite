# frozen_string_literal: true

FactoryBot.define do
  factory :billing_plan, class: "Billing::Plan" do
    sequence(:key) { |n| "plan_#{n}" }
    sequence(:name) { |n| "Plan #{n}" }
    description { "Plan description" }
    plan_type { "recurring" }
    interval { "month" }
    amount_cents { 1200 }
    currency { "eur" }
    highlighted { false }
    published { true }
    sort_order { 0 }
    metadata { {} }

    trait :free do
      key { "free" }
      name { "Free" }
      plan_type { "free" }
      interval { nil }
      amount_cents { nil }
    end

    trait :pro do
      key { "pro" }
      name { "Pro" }
      plan_type { "recurring" }
      interval { "month" }
      amount_cents { 1200 }
      highlighted { true }
    end

    trait :sprint do
      key { "sprint" }
      name { "Sprint" }
      plan_type { "one_time" }
      interval { nil }
      amount_cents { 2500 }
      metadata { { "duration_label" => "30 days (one-time)" } }
    end
  end
end


