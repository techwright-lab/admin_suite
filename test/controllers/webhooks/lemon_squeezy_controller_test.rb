# frozen_string_literal: true

require "test_helper"

class Webhooks::LemonSqueezyControllerTest < ActionDispatch::IntegrationTest
  test "rejects webhook with invalid signature" do
    ENV["LEMONSQUEEZY_WEBHOOK_SECRET"] = "secret"

    post webhooks_lemon_squeezy_path, params: { hello: "world" }.to_json, headers: { "Content-Type" => "application/json", "X-Signature" => "nope" }
    assert_response :unauthorized
  end

  test "stores webhook event and enqueues processing when signature is valid" do
    ENV["LEMONSQUEEZY_WEBHOOK_SECRET"] = "secret"

    payload = { meta: { event_name: "subscription_created" }, data: { id: "sub_1", attributes: { status: "active" } } }
    raw = payload.to_json
    sig = OpenSSL::HMAC.hexdigest("SHA256", "secret", raw)

    assert_difference -> { Billing::WebhookEvent.count }, 1 do
      assert_enqueued_with(job: Billing::ProcessWebhookEventJob) do
        post webhooks_lemon_squeezy_path, params: raw, headers: { "Content-Type" => "application/json", "X-Signature" => sig, "X-Event-Id" => "evt_1" }
      end
    end

    assert_response :ok
    evt = Billing::WebhookEvent.find_by(provider: "lemonsqueezy", idempotency_key: "evt_1")
    assert_equal "subscription_created", evt.event_type
  end

  test "is idempotent on repeated event id" do
    ENV["LEMONSQUEEZY_WEBHOOK_SECRET"] = "secret"

    payload = { meta: { event_name: "subscription_updated" }, data: { id: "sub_1", attributes: { status: "active" } } }
    raw = payload.to_json
    sig = OpenSSL::HMAC.hexdigest("SHA256", "secret", raw)

    post webhooks_lemon_squeezy_path, params: raw, headers: { "Content-Type" => "application/json", "X-Signature" => sig, "X-Event-Id" => "evt_same" }
    post webhooks_lemon_squeezy_path, params: raw, headers: { "Content-Type" => "application/json", "X-Signature" => sig, "X-Event-Id" => "evt_same" }

    assert_equal 1, Billing::WebhookEvent.where(provider: "lemonsqueezy", idempotency_key: "evt_same").count
  end
end


