# frozen_string_literal: true

FactoryBot.define do
  factory :billing_webhook_event, class: "Billing::WebhookEvent" do
    provider { "lemonsqueezy" }
    sequence(:idempotency_key) { |n| "evt_#{n}" }
    event_type { "subscription_created" }
    payload { {} }
    status { "pending" }
    received_at { Time.current }
    processed_at { nil }
    error_message { nil }
  end
end


