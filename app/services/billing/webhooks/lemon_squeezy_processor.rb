# frozen_string_literal: true

module Billing
  module Webhooks
    # Processes LemonSqueezy webhook events and syncs subscription state.
    #
    # Payload format can vary by event type and LemonSqueezy version; we parse defensively.
    class LemonSqueezyProcessor
      # @param webhook_event [Billing::WebhookEvent]
      def initialize(webhook_event)
        @webhook_event = webhook_event
        @payload = webhook_event.payload || {}
      end

      # @return [void]
      def run
        event_type = extract_event_type
        webhook_event.update!(event_type: event_type) if webhook_event.event_type.blank? && event_type.present?

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        handled = handle_subscription_event(event_type)
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
        Rails.logger.info("[billing] lemonsqueezy webhook processed event_type=#{event_type} handled=#{handled} duration_ms=#{duration_ms} id=#{webhook_event.id}")

        webhook_event.update!(
          status: handled ? "processed" : "ignored",
          processed_at: Time.current
        )
      rescue => e
        ExceptionNotifier.notify(
          e,
          context: "payment",
          severity: "error",
          tags: { provider: "lemonsqueezy", operation: "webhook_process", event_type: webhook_event.event_type },
          webhook_event_id: webhook_event.id
        )
        webhook_event.update!(status: "failed", processed_at: Time.current, error_message: "#{e.class}: #{e.message}")
      end

      private

      attr_reader :webhook_event, :payload

      def extract_event_type
        payload.dig("meta", "event_name") ||
          payload["event_name"] ||
          payload["type"] ||
          payload.dig("meta", "event") ||
          payload.dig("meta", "name")
      end

      def handle_subscription_event(event_type)
        return false if event_type.blank?

        # Normalize typical LemonSqueezy event names
        normalized = event_type.to_s.downcase
        return false unless normalized.include?("subscription")

        subscription_data = payload["data"] || payload.dig("data", "data") || {}
        subscription_id = subscription_data["id"] || payload.dig("data", "id")
        attributes = subscription_data["attributes"] || payload.dig("data", "attributes") || {}

        user = resolve_user(attributes)
        return false if user.nil?

        plan = resolve_plan(attributes)

        subscription = Billing::Subscription.find_or_initialize_by(
          provider: "lemonsqueezy",
          external_subscription_id: subscription_id.to_s,
          user: user
        )

        subscription.plan = plan if plan.present?
        subscription.status = normalize_status(attributes["status"] || attributes["state"] || subscription.status)
        subscription.trial_ends_at = parse_time(attributes["trial_ends_at"] || attributes["trial_end_date"] || attributes["trial_end"])
        subscription.current_period_starts_at = parse_time(attributes["current_period_start"] || attributes["current_period_starts_at"] || attributes["renews_at"])
        subscription.current_period_ends_at = parse_time(attributes["current_period_end"] || attributes["current_period_ends_at"] || attributes["ends_at"] || attributes["renews_at"])
        subscription.cancel_at_period_end = truthy?(attributes["cancel_at_period_end"] || attributes["cancel_at_end"] || false)
        subscription.cancelled_at = parse_time(attributes["cancelled_at"])
        subscription.metadata = (subscription.metadata || {}).merge(raw: attributes)

        subscription.save!

        # Sync customer mapping when possible
        external_customer_id = attributes["customer_id"] || attributes["customer"] || payload.dig("meta", "customer_id")
        if external_customer_id.present?
          Billing::Customer.find_or_create_by!(user: user, provider: "lemonsqueezy") do |c|
            c.external_customer_id = external_customer_id.to_s
          end
        end

        true
      end

      def resolve_user(attributes)
        user_id = dig_custom_user_id(attributes)
        return User.find_by(id: user_id) if user_id.present?

        email = attributes["user_email"] || attributes["email"] || attributes.dig("checkout_data", "email")
        return User.find_by(email_address: email.to_s.downcase) if email.present?

        nil
      end

      def dig_custom_user_id(attributes)
        attributes.dig("checkout_data", "custom", "user_id") ||
          attributes.dig("checkout_data", "custom_data", "user_id") ||
          attributes.dig("custom", "user_id") ||
          attributes.dig("custom_data", "user_id") ||
          payload.dig("meta", "custom_data", "user_id") ||
          payload.dig("meta", "custom", "user_id")
      end

      def resolve_plan(attributes)
        variant_id = attributes["variant_id"] ||
          attributes.dig("variant", "id") ||
          attributes.dig("variant", "data", "id") ||
          payload.dig("data", "relationships", "variant", "data", "id")

        return nil if variant_id.blank?

        mapping = Billing::ProviderMapping.find_by(provider: "lemonsqueezy", external_variant_id: variant_id.to_s)
        mapping&.plan
      end

      def normalize_status(raw)
        value = raw.to_s.downcase
        return "inactive" if value.blank?

        case value
        when "active" then "active"
        when "trialing", "on_trial" then "trialing"
        when "cancelled", "canceled" then "cancelled"
        when "expired" then "expired"
        when "past_due" then "past_due"
        else
          "inactive"
        end
      end

      def parse_time(value)
        return nil if value.blank?
        return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def truthy?(value)
        value == true || value.to_s == "true" || value.to_s == "1"
      end
    end
  end
end
