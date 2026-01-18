# frozen_string_literal: true

module Billing
  module Webhooks
    # Processes LemonSqueezy webhook events and syncs subscription state.
    #
    # Payload format can vary by event type and LemonSqueezy version; we parse defensively.
    class LemonSqueezyProcessor < ApplicationService
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
        log_info("webhook processed event_type=#{event_type} handled=#{handled} duration_ms=#{duration_ms} id=#{webhook_event.id}")

        webhook_event.update!(
          status: handled ? "processed" : "ignored",
          processed_at: Time.current
        )
      rescue => e
        notify_error(
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

        normalized = event_type.to_s.downcase
        return handle_order_event if normalized.include?("order")
        return handle_subscription_invoice_event if subscription_invoice_event?(normalized)
        return false unless normalized.include?("subscription")

        handle_subscription_payload
      end

      # @return [Boolean]
      def handle_subscription_payload
        subscription_data = payload["data"] || payload.dig("data", "data") || {}
        attributes = subscription_data["attributes"] || payload.dig("data", "attributes") || {}
        subscription_id = subscription_data["id"] || payload.dig("data", "id") || attributes["subscription_id"]
        return false if subscription_id.blank?

        user = resolve_user(attributes)
        return false if user.nil?

        plan = resolve_plan(attributes)
        urls = extract_subscription_urls(attributes)

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

        # Store payment method details
        subscription.card_brand = attributes["card_brand"] if attributes["card_brand"].present?
        subscription.card_last_four = attributes["card_last_four"] if attributes["card_last_four"].present?

        metadata = subscription.metadata || {}
        metadata["raw"] = attributes
        metadata["order_id"] = attributes["order_id"] if attributes["order_id"].present?
        metadata["customer_id"] = attributes["customer_id"] if attributes["customer_id"].present?
        subscription.metadata = metadata

        apply_subscription_urls(subscription, urls)

        subscription.save!

        customer = sync_customer_mapping(user: user, attributes: attributes, urls: urls)
        link_order_to_subscription(subscription, customer, attributes["order_id"])

        # Deactivate any active one-time purchase grants when subscription activates
        # This ensures only one plan is active at a time
        if subscription.status == "active"
          deactivate_purchase_grants_for_subscription(user, subscription)
        end

        true
      end

      # @return [Boolean]
      def handle_subscription_invoice_event
        invoice_data = payload["data"] || payload.dig("data", "data") || {}
        attributes = invoice_data["attributes"] || payload.dig("data", "attributes") || {}
        subscription_id = attributes["subscription_id"] || invoice_data["subscription_id"]
        return false if subscription_id.blank?

        subscription = Billing::Subscription.find_by(provider: "lemonsqueezy", external_subscription_id: subscription_id.to_s)
        return false if subscription.nil?

        invoice_url = attributes.dig("urls", "invoice_url")
        return false if invoice_url.blank?

        metadata = subscription.metadata || {}
        metadata["latest_invoice_id"] = invoice_data["id"] || attributes["id"]
        metadata["latest_invoice_status"] = attributes["status"]
        metadata["latest_invoice_total"] = attributes["total"]
        metadata["latest_invoice_currency"] = attributes["currency"]
        subscription.latest_invoice_url = invoice_url
        subscription.update!(metadata: metadata)

        true
      end

      # @return [Boolean]
      def handle_order_event
        order_data = payload["data"] || payload.dig("data", "data") || {}
        attributes = order_data["attributes"] || payload.dig("data", "attributes") || {}
        user = resolve_user(attributes)
        return false if user.nil?

        order_id = order_data["id"] || attributes["id"]
        return false if order_id.blank?

        receipt_url = attributes.dig("urls", "receipt")
        plan = resolve_plan(attributes)
        subscription = resolve_subscription_for_order(user, attributes)
        customer = sync_customer_mapping(user: user, attributes: attributes)

        order = Billing::Order.find_or_initialize_by(provider: "lemonsqueezy", external_order_id: order_id.to_s)
        order.user = user
        order.customer = customer
        order.subscription = subscription
        order.status = attributes["status"]
        order.total_cents = attributes["total"]
        order.currency = attributes["currency"]&.downcase
        order.order_number = attributes["order_number"]&.to_s
        order.identifier = attributes["identifier"]&.to_s
        order.receipt_url = receipt_url
        order.metadata = (order.metadata || {}).merge(raw: attributes)
        order.save!

        if receipt_url.present?
          customer.latest_receipt_url = receipt_url if customer.present?
          customer.save! if customer&.changed?

          update_subscription_receipt(subscription, order) if subscription.present?
        end

        # For one-time purchases, grant entitlements and cancel any active subscriptions
        if plan&.one_time?
          grant_one_time_entitlements(user: user, plan: plan, order: order)
          cancel_subscription_for_one_time_purchase(user, plan, order)
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
          attributes.dig("first_order_item", "variant_id") ||
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

      # @param normalized [String]
      # @return [Boolean]
      def subscription_invoice_event?(normalized)
        return true if normalized.include?("subscription_payment")
        return true if normalized.include?("subscription_invoice")

        payload_type = payload.dig("data", "type") || payload.dig("data", "data", "type")
        payload_type.to_s == "subscription-invoices"
      end

      # @param attributes [Hash]
      # @return [Hash]
      def extract_subscription_urls(attributes)
        urls = attributes["urls"] || {}
        {
          "customer_portal_url" => urls["customer_portal"],
          "update_payment_method_url" => urls["update_payment_method"],
          "update_subscription_url" => urls["customer_portal_update_subscription"]
        }.compact
      end

      # @param user [User]
      # @param attributes [Hash]
      # @param urls [Hash, nil]
      # @return [Billing::Customer, nil]
      def sync_customer_mapping(user:, attributes:, urls: nil)
        external_customer_id = attributes["customer_id"] || attributes["customer"] || payload.dig("meta", "customer_id")
        return if external_customer_id.blank?

        customer = Billing::Customer.find_or_create_by!(user: user, provider: "lemonsqueezy") do |c|
          c.external_customer_id = external_customer_id.to_s
        end

        if customer.external_customer_id != external_customer_id.to_s
          customer.update!(external_customer_id: external_customer_id.to_s)
        end

        if urls.present? && urls["customer_portal_url"].present?
          customer.customer_portal_url = urls["customer_portal_url"]
          customer.save! if customer.changed?
        end

        customer
      end

      # @param order_id [String, Integer, nil]
      # @param attributes [Hash]
      # @param receipt_url [String, nil]
      # @return [Hash]
      # @param subscription [Billing::Subscription]
      # @param urls [Hash]
      # @return [void]
      def apply_subscription_urls(subscription, urls)
        return if urls.blank?

        subscription.assign_attributes(urls)
      end

      # @param user [User]
      # @param attributes [Hash]
      # @return [Billing::Subscription, nil]
      def resolve_subscription_for_order(user, attributes)
        plan = resolve_plan(attributes)
        return user.billing_subscriptions.where(provider: "lemonsqueezy").order(updated_at: :desc).first if plan.blank?

        user.billing_subscriptions.find_by(provider: "lemonsqueezy", plan: plan)
      end

      # @param subscription [Billing::Subscription]
      # @param order [Billing::Order]
      # @return [void]
      def update_subscription_receipt(subscription, order)
        subscription.latest_receipt_url = order.receipt_url

        metadata = subscription.metadata || {}
        metadata["latest_order_id"] = order.external_order_id
        metadata["latest_order_number"] = order.order_number
        metadata["latest_order_identifier"] = order.identifier
        metadata["latest_order_status"] = order.status
        metadata["latest_order_total"] = order.total_cents
        metadata["latest_order_currency"] = order.currency
        subscription.update!(metadata: metadata)
      end

      # @param subscription [Billing::Subscription]
      # @param customer [Billing::Customer, nil]
      # @param order_id [String, Integer, nil]
      # @return [void]
      def link_order_to_subscription(subscription, customer, order_id)
        return if order_id.blank?

        order = Billing::Order.find_by(provider: "lemonsqueezy", external_order_id: order_id.to_s)
        return if order.nil?

        updates = {}
        updates[:billing_subscription_id] = subscription.id if order.billing_subscription_id != subscription.id
        updates[:billing_customer_id] = customer.id if customer.present? && order.billing_customer_id != customer.id
        order.update!(updates) if updates.any?
      end

      # Creates an EntitlementGrant for one-time purchases (e.g., Sprint plan).
      #
      # @param user [User]
      # @param plan [Billing::Plan]
      # @param order [Billing::Order]
      # @return [Billing::EntitlementGrant, nil]
      def grant_one_time_entitlements(user:, plan:, order:)
        return unless plan&.one_time?

        # Check for existing grant from the same order to avoid duplicates
        existing = Billing::EntitlementGrant.find_by(
          user: user,
          source: "purchase",
          reason: "one_time_purchase:#{order.external_order_id}"
        )
        return existing if existing.present?

        # Duration from plan metadata or default 30 days
        duration_days = plan.metadata&.dig("duration_days")&.to_i
        duration_days = 30 if duration_days.nil? || duration_days <= 0

        starts_at = Time.current
        expires_at = starts_at + duration_days.days

        # Build entitlements map from plan entitlements
        entitlements = build_entitlements_from_plan(plan)

        Billing::EntitlementGrant.create!(
          user: user,
          plan: plan,
          source: "purchase",
          reason: "one_time_purchase:#{order.external_order_id}",
          starts_at: starts_at,
          expires_at: expires_at,
          entitlements: entitlements,
          metadata: {
            plan_key: plan.key,
            plan_name: plan.name,
            order_id: order.external_order_id,
            order_number: order.order_number,
            amount_cents: order.total_cents,
            currency: order.currency
          }
        )
      end

      # Builds entitlements hash from plan's PlanEntitlements.
      #
      # @param plan [Billing::Plan]
      # @return [Hash] Entitlements map keyed by feature_key
      def build_entitlements_from_plan(plan)
        plan.plan_entitlements.includes(:feature).each_with_object({}) do |pe, hash|
          next unless pe.enabled

          entry = { "enabled" => true }
          entry["limit"] = pe.limit if pe.limit.present?
          hash[pe.feature.key] = entry
        end
      end

      # Deactivates active one-time purchase grants when a subscription is created/activated.
      # This ensures only one plan is active at a time.
      #
      # @param user [User]
      # @param subscription [Billing::Subscription]
      # @return [void]
      def deactivate_purchase_grants_for_subscription(user, subscription)
        grants = Billing::EntitlementGrant
          .where(user: user, source: "purchase")
          .where("reason LIKE ?", "one_time_purchase:%")
          .where("starts_at <= ? AND expires_at > ?", Time.current, Time.current)

        return if grants.empty?

        grants.find_each do |grant|
          grant.update!(
            expires_at: Time.current,
            metadata: grant.metadata.merge(
              "deactivated_reason" => "subscription_activated",
              "deactivated_at" => Time.current.iso8601,
              "original_expires_at" => grant.expires_at_was&.iso8601,
              "subscription_id" => subscription.id
            )
          )

          log_info(
            "deactivated purchase grant for subscription " \
            "user_id=#{user.id} grant_id=#{grant.id} subscription_id=#{subscription.id}"
          )
        end
      end

      # Cancels active subscriptions when a one-time purchase is made.
      # This ensures only one plan is active at a time.
      # Note: This is a safety net; checkout controller also cancels subscriptions.
      #
      # @param user [User]
      # @param plan [Billing::Plan]
      # @param order [Billing::Order]
      # @return [void]
      def cancel_subscription_for_one_time_purchase(user, plan, order)
        subscriptions = user.billing_subscriptions
          .where(provider: "lemonsqueezy")
          .where(status: %w[active trialing])
          .where(cancel_at_period_end: [ false, nil ])

        return if subscriptions.empty?

        provider = Billing::Providers::LemonSqueezy.new

        subscriptions.find_each do |subscription|
          begin
            provider.cancel_subscription(subscription: subscription)

            log_info(
              "cancelled subscription for one-time purchase " \
              "user_id=#{user.id} subscription_id=#{subscription.id} order_id=#{order.id} plan=#{plan.key}"
            )
          rescue => e
            notify_error(
              e,
              context: "billing",
              severity: "error",
              user: user,
              tags: { provider: "lemonsqueezy", operation: "webhook_cancel_subscription" },
              subscription_id: subscription.id,
              order_id: order.id,
              plan_key: plan.key
            )
          end
        end
      end
    end
  end
end
