# frozen_string_literal: true

module Billing
  module Providers
    # LemonSqueezy payment provider implementation.
    #
    # Uses the LemonSqueezy API to create hosted checkout URLs and relies on webhooks
    # to sync subscription state back into the app.
    class LemonSqueezy
      include HTTParty

      base_uri "https://api.lemonsqueezy.com/v1"

      # @param api_key [String, nil]
      def initialize(api_key: nil)
        @api_key = api_key.presence || Rails.application.credentials.dig(:lemonsqueezy, :api_key) || ENV["LEMONSQUEEZY_API_KEY"]
      end

      # Creates a hosted checkout URL for the given plan.
      #
      # Requires a Billing::ProviderMapping for provider=lemonsqueezy with:
      # - external_variant_id
      # - metadata["store_id"]
      #
      # @param user [User]
      # @param plan [Billing::Plan]
      # @return [String] hosted checkout URL
      def create_checkout(user:, plan:)
        mapping = Billing::ProviderMapping.find_by!(provider: "lemonsqueezy", plan: plan)
        store_id = Rails.application.credentials.dig(:lemonsqueezy, :store_id) || ENV["LEMONSQUEEZY_STORE_ID"] || mapping.metadata["store_id"].presence
        variant_id = mapping.external_variant_id.presence

        raise "Missing LemonSqueezy store_id in provider mapping metadata" if store_id.blank?
        raise "Missing LemonSqueezy external_variant_id in provider mapping" if variant_id.blank?
        raise "Missing LemonSqueezy API key" if api_key.blank?

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        body = {
          data: {
            type: "checkouts",
            attributes: {
              checkout_data: {
                email: user.email_address,
                custom: {
                  user_id: user.id.to_s
                }
              }
            },
            relationships: {
              store: { data: { type: "stores", id: store_id.to_s } },
              variant: { data: { type: "variants", id: variant_id.to_s } }
            }
          }
        }

        response = self.class.post(
          "/checkouts",
          headers: request_headers,
          body: body.to_json
        )

        parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
        url = parsed.dig("data", "attributes", "url") ||
          parsed.dig("data", "attributes", "checkout_url") ||
          parsed.dig("data", "attributes", "checkout_url_string")

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
        Rails.logger.info("[billing] lemonsqueezy checkout create status=#{response.code} duration_ms=#{duration_ms} plan_key=#{plan.key} user_id=#{user.id}")

        raise "LemonSqueezy checkout creation failed (status=#{response.code})" unless response.code.to_i.between?(200, 299)
        raise "LemonSqueezy checkout URL missing from response" if url.blank?

        url
      rescue => e
        ExceptionNotifier.notify(
          e,
          context: "payment",
          severity: "error",
          tags: { provider: "lemonsqueezy", operation: "create_checkout" },
          user: { id: user&.id, email: user&.email_address },
          plan_key: plan&.key
        )
        raise
      end

      # Retrieves the LemonSqueezy customer portal URL for a user.
      #
      # @param customer [Billing::Customer] the customer record with external_customer_id
      # @return [String] the customer portal URL
      def customer_portal_url(customer:)
        raise "Missing LemonSqueezy API key" if api_key.blank?
        raise "Customer external_customer_id is required" if customer&.external_customer_id.blank?

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        response = self.class.post(
          "/customers/#{customer.external_customer_id}/portal",
          headers: request_headers
        )

        parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
        url = parsed.dig("data", "attributes", "url") ||
          parsed.dig("data", "attributes", "urls", "customer_portal")

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
        Rails.logger.info("[billing] lemonsqueezy customer_portal status=#{response.code} duration_ms=#{duration_ms} customer_id=#{customer.id}")

        raise "LemonSqueezy customer portal request failed (status=#{response.code})" unless response.code.to_i.between?(200, 299)
        raise "LemonSqueezy customer portal URL missing from response" if url.blank?

        url
      rescue => e
        ExceptionNotifier.notify(
          e,
          context: "payment",
          severity: "error",
          tags: { provider: "lemonsqueezy", operation: "customer_portal" },
          customer_id: customer&.id
        )
        raise
      end

      # Cancels a subscription at period end.
      #
      # @param subscription [Billing::Subscription]
      # @return [Boolean] true if successful
      def cancel_subscription(subscription:)
        raise "Missing LemonSqueezy API key" if api_key.blank?
        raise "Subscription external_subscription_id is required" if subscription&.external_subscription_id.blank?

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        body = {
          data: {
            type: "subscriptions",
            id: subscription.external_subscription_id,
            attributes: {
              cancelled: true
            }
          }
        }

        response = self.class.patch(
          "/subscriptions/#{subscription.external_subscription_id}",
          headers: request_headers,
          body: body.to_json
        )

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
        Rails.logger.info("[billing] lemonsqueezy cancel_subscription status=#{response.code} duration_ms=#{duration_ms} subscription_id=#{subscription.id}")

        unless response.code.to_i.between?(200, 299)
          raise "LemonSqueezy cancel subscription failed (status=#{response.code})"
        end

        # Update local record optimistically (webhook will confirm)
        subscription.update!(cancel_at_period_end: true)
        true
      rescue => e
        ExceptionNotifier.notify(
          e,
          context: "payment",
          severity: "error",
          tags: { provider: "lemonsqueezy", operation: "cancel_subscription" },
          subscription_id: subscription&.id
        )
        raise
      end

      # Resumes a cancelled subscription (removes cancellation).
      #
      # @param subscription [Billing::Subscription]
      # @return [Boolean] true if successful
      def resume_subscription(subscription:)
        raise "Missing LemonSqueezy API key" if api_key.blank?
        raise "Subscription external_subscription_id is required" if subscription&.external_subscription_id.blank?

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        body = {
          data: {
            type: "subscriptions",
            id: subscription.external_subscription_id,
            attributes: {
              cancelled: false
            }
          }
        }

        response = self.class.patch(
          "/subscriptions/#{subscription.external_subscription_id}",
          headers: request_headers,
          body: body.to_json
        )

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
        Rails.logger.info("[billing] lemonsqueezy resume_subscription status=#{response.code} duration_ms=#{duration_ms} subscription_id=#{subscription.id}")

        unless response.code.to_i.between?(200, 299)
          raise "LemonSqueezy resume subscription failed (status=#{response.code})"
        end

        # Update local record optimistically (webhook will confirm)
        subscription.update!(cancel_at_period_end: false)
        true
      rescue => e
        ExceptionNotifier.notify(
          e,
          context: "payment",
          severity: "error",
          tags: { provider: "lemonsqueezy", operation: "resume_subscription" },
          subscription_id: subscription&.id
        )
        raise
      end

      private

      attr_reader :api_key

      def request_headers
        {
          "Authorization" => "Bearer #{api_key}",
          "Accept" => "application/vnd.api+json",
          "Content-Type" => "application/vnd.api+json"
        }
      end
    end
  end
end
