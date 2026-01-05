# frozen_string_literal: true

require "test_helper"

class Billing::Webhooks::LemonSqueezyProcessorTest < ActiveSupport::TestCase
  test "creates/updates subscription and links to plan via provider mapping" do
    user = create(:user)
    plan = create(:billing_plan, :pro)
    create(:billing_provider_mapping, plan: plan, external_variant_id: "variant_123", metadata: { "store_id" => "store_1" })

    event = create(:billing_webhook_event, payload: {
      "meta" => { "event_name" => "subscription_created" },
      "data" => {
        "id" => "sub_123",
        "attributes" => {
          "status" => "active",
          "variant_id" => "variant_123",
          "checkout_data" => { "custom" => { "user_id" => user.id.to_s } }
        }
      }
    })

    Billing::Webhooks::LemonSqueezyProcessor.new(event).run

    sub = Billing::Subscription.find_by(provider: "lemonsqueezy", external_subscription_id: "sub_123")
    assert_not_nil sub
    assert_equal user.id, sub.user_id
    assert_equal plan.id, sub.plan_id
    assert_equal "active", sub.status
  end
end


