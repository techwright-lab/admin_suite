# frozen_string_literal: true

module Billing
  # View helpers for checking entitlements in ERB templates.
  module EntitlementsHelper
    # @param feature_key [String, Symbol]
    # @return [Boolean]
    def entitled?(feature_key)
      current_entitlements.allowed?(feature_key)
    end

    # @param feature_key [String, Symbol]
    # @return [Integer, nil]
    def entitlement_remaining(feature_key)
      current_entitlements.remaining(feature_key)
    end

    # @return [Boolean]
    def insight_trial_active?
      current_entitlements.insight_trial_active?
    end

    # @return [String, nil]
    def insight_trial_time_remaining_in_words
      current_entitlements.insight_trial_time_remaining_in_words
    end

    # @return [Symbol]
    def subscription_status
      current_entitlements.subscription_status
    end

    # @return [Billing::Plan, nil]
    def current_plan
      current_entitlements.plan
    end

    private

    def current_entitlements
      @current_entitlements ||= Billing::Entitlements.for(Current.user)
    end
  end
end
