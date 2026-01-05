# frozen_string_literal: true

module Billing
  # Controller for managing subscription actions (cancel/resume).
  class SubscriptionsController < ApplicationController
    before_action :set_subscription

    # POST /billing/subscription/cancel
    #
    # Sets the subscription to cancel at period end.
    def cancel
      unless @subscription
        redirect_to settings_path(tab: "billing", subtab: "subscription"),
          alert: "No active subscription found."
        return
      end

      if @subscription.cancel_at_period_end?
        redirect_to settings_path(tab: "billing", subtab: "subscription"),
          notice: "Subscription is already set to cancel."
        return
      end

      provider = Billing::Providers::LemonSqueezy.new
      provider.cancel_subscription(subscription: @subscription)

      redirect_to settings_path(tab: "billing", subtab: "subscription"),
        notice: "Your subscription will cancel at the end of the current billing period."
    rescue StandardError => e
      Rails.logger.error("[billing] Failed to cancel subscription: #{e.message}")
      redirect_to settings_path(tab: "billing", subtab: "subscription"),
        alert: "Failed to cancel subscription. Please try again or contact support."
    end

    # POST /billing/subscription/resume
    #
    # Removes the cancellation from a subscription.
    def resume
      unless @subscription
        redirect_to settings_path(tab: "billing", subtab: "subscription"),
          alert: "No active subscription found."
        return
      end

      unless @subscription.cancel_at_period_end?
        redirect_to settings_path(tab: "billing", subtab: "subscription"),
          notice: "Subscription is not set to cancel."
        return
      end

      provider = Billing::Providers::LemonSqueezy.new
      provider.resume_subscription(subscription: @subscription)

      redirect_to settings_path(tab: "billing", subtab: "subscription"),
        notice: "Your subscription has been resumed and will continue renewing."
    rescue StandardError => e
      Rails.logger.error("[billing] Failed to resume subscription: #{e.message}")
      redirect_to settings_path(tab: "billing", subtab: "subscription"),
        alert: "Failed to resume subscription. Please try again or contact support."
    end

    private

    def set_subscription
      entitlements = Billing::Entitlements.for(Current.user)
      @subscription = entitlements.active_subscription
    end
  end
end
