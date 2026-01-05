# frozen_string_literal: true

module Webhooks
  # Receives LemonSqueezy webhooks.
  #
  # Stores events for idempotency and async processing, then returns 200 quickly.
  class LemonSqueezyController < ApplicationController
    allow_unauthenticated_access
    skip_before_action :verify_authenticity_token

    # POST /webhooks/lemon_squeezy
    def create
      raw_body = request.raw_post.to_s
      signature = signature_header

      unless valid_signature?(raw_body, signature)
        Rails.logger.warn("[billing] Invalid LemonSqueezy webhook signature")
        head :unauthorized
        return
      end

      payload = JSON.parse(raw_body) rescue {}
      idempotency_key = request.headers["X-Event-Id"].presence || Digest::SHA256.hexdigest(raw_body)
      event_type = payload.dig("meta", "event_name") || payload["event_name"] || payload["type"]

      event = Billing::WebhookEvent.find_or_create_by!(provider: "lemonsqueezy", idempotency_key: idempotency_key) do |we|
        we.event_type = event_type
        we.payload = payload
        we.received_at = Time.current
      end

      Rails.logger.info("[billing] lemonsqueezy webhook received event_type=#{event_type} key=#{idempotency_key} status=#{event.status}")
      Billing::ProcessWebhookEventJob.perform_later(event) if event.processed_at.blank? && event.status == "pending"

      head :ok
    end

    private

    def signature_header
      request.headers["X-Signature"].presence ||
        request.headers["X-LemonSqueezy-Signature"].presence ||
        request.headers["X-LemonSqueezy-Signature".downcase].presence
    end

    def webhook_secret
      Rails.application.credentials.dig(:lemonsqueezy, :webhook_secret) || ENV["LEMONSQUEEZY_WEBHOOK_SECRET"]
    end

    def valid_signature?(raw_body, signature)
      secret = webhook_secret.to_s
      return false if secret.blank?
      return false if signature.blank?

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, raw_body)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
    rescue => e
      ExceptionNotifier.notify(
        e,
        context: "payment",
        severity: "warning",
        tags: { provider: "lemonsqueezy", operation: "webhook_signature" },
        error: "signature_verification_failed"
      )
      false
    end
  end
end


