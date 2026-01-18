# frozen_string_literal: true

module Billing
  # Handles plan switching logic, ensuring only one active plan at a time.
  #
  # Subscription → Sprint: Cancels subscription at period end, Sprint activates immediately.
  # Sprint → Subscription: Deactivates Sprint grant, subscription activates immediately.
  #
  # LemonSqueezy handles proration automatically for subscription changes.
  class PlanSwitcher < ApplicationService
    attr_reader :user

    # @param user [User]
    def initialize(user)
      @user = user
    end

    # Prepares for switching to a new plan by cancelling conflicting plans.
    #
    # @param new_plan [Billing::Plan]
    # @return [Hash] { cancelled_subscription: Boolean, deactivated_grant: Boolean }
    def prepare_switch(new_plan)
      result = { cancelled_subscription: false, deactivated_grant: false }

      if new_plan.one_time?
        # Switching to one-time plan (Sprint) - cancel any active subscription
        result[:cancelled_subscription] = cancel_active_subscription
      else
        # Switching to subscription plan - deactivate any active one-time purchase grants
        result[:deactivated_grant] = deactivate_purchase_grants
      end

      result
    end

    # Cancels the user's active subscription at period end.
    # The user keeps access until the billing period ends, then it expires.
    #
    # @return [Boolean] true if a subscription was cancelled
    def cancel_active_subscription
      subscription = active_subscription
      return false if subscription.nil?

      # Skip if already cancelled
      return false if subscription.cancel_at_period_end

      provider = Billing::Providers::LemonSqueezy.new
      provider.cancel_subscription(subscription: subscription)

      log_info(
        "cancelled subscription for one-time purchase " \
        "user_id=#{user.id} subscription_id=#{subscription.id}"
      )

      true
    rescue => e
      notify_error(
        e,
        context: "billing",
        severity: "error",
        user: user,
        tags: { operation: "plan_switch", action: "cancel_subscription" },
        subscription_id: subscription&.id
      )
      # Don't block the checkout - subscription will remain active alongside Sprint
      false
    end

    # Deactivates active one-time purchase grants (e.g., Sprint).
    # This allows subscription features to take over.
    #
    # @return [Boolean] true if any grants were deactivated
    def deactivate_purchase_grants
      grants = active_purchase_grants
      return false if grants.empty?

      grants.each do |grant|
        # Set expires_at to now to deactivate
        grant.update!(
          expires_at: Time.current,
          metadata: grant.metadata.merge(
            "deactivated_reason" => "subscription_switch",
            "deactivated_at" => Time.current.iso8601,
            "original_expires_at" => grant.expires_at_was&.iso8601
          )
        )

        log_info(
          "deactivated purchase grant for subscription " \
          "user_id=#{user.id} grant_id=#{grant.id}"
        )
      end

      true
    rescue => e
      notify_error(
        e,
        context: "billing",
        severity: "error",
        user: user,
        tags: { operation: "plan_switch", action: "deactivate_grants" },
        grant_ids: grants&.map(&:id)
      )
      false
    end

    # Returns the current plan type the user is on.
    #
    # @return [Symbol] :subscription, :one_time, :free
    def current_plan_type
      return :one_time if active_purchase_grants.any?
      return :subscription if active_subscription.present?

      :free
    end

    # Returns whether switching to the given plan requires cancellation.
    #
    # @param new_plan [Billing::Plan]
    # @return [Boolean]
    def requires_cancellation?(new_plan)
      return false if current_plan_type == :free

      if new_plan.one_time?
        # Switching to Sprint requires cancelling subscription
        current_plan_type == :subscription
      else
        # Switching to subscription requires deactivating Sprint
        current_plan_type == :one_time
      end
    end

    private

    def active_subscription
      @active_subscription ||= user.billing_subscriptions
        .where(provider: "lemonsqueezy")
        .where(status: %w[active trialing])
        .where(cancel_at_period_end: [ false, nil ])
        .order(updated_at: :desc)
        .first
    end

    def active_purchase_grants
      @active_purchase_grants ||= Billing::EntitlementGrant
        .where(user: user, source: "purchase")
        .where("reason LIKE ?", "one_time_purchase:%")
        .where("starts_at <= ? AND expires_at > ?", Time.current, Time.current)
        .to_a
    end
  end
end
