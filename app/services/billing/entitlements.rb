# frozen_string_literal: true

module Billing
  # Computes effective entitlements for a user by combining:
  # - Plan entitlements (from the active subscription, or Free fallback)
  # - Active entitlement grants (trials/promos/admin overrides)
  # - Usage counters (for quota remaining)
  #
  # Usage:
  #   ent = Billing::Entitlements.for(Current.user)
  #   ent.allowed?(:pattern_detection)
  #   ent.remaining(:ai_summaries)
  class Entitlements
    class << self
      # @param user [User]
      # @param at [Time]
      # @return [Billing::Entitlements]
      def for(user, at: Time.current)
        new(user, at: at)
      end
    end

    attr_reader :user, :at

    # @param user [User]
    # @param at [Time]
    def initialize(user, at: Time.current)
      @user = user
      @at = at
    end

    # @return [Billing::Plan, nil]
    def plan
      active_subscription&.plan || Billing::Plan.find_by(key: "free")
    end

    # @param feature_key [String, Symbol]
    # @return [Boolean]
    def allowed?(feature_key)
      spec = entitlement_spec(feature_key)
      spec.fetch("enabled", false) == true
    end

    # @param feature_key [String, Symbol]
    # @return [Integer, nil]
    def limit(feature_key)
      spec = entitlement_spec(feature_key)
      spec["limit"]
    end

    # @param feature_key [String, Symbol]
    # @return [Integer, nil]
    def remaining(feature_key)
      lim = limit(feature_key)
      return nil if lim.nil?

      used = usage_for(feature_key)
      [ lim - used, 0 ].max
    end

    # Returns the active subscription for the user.
    #
    # @return [Billing::Subscription, nil]
    def active_subscription
      @active_subscription ||= Billing::Subscription.where(user: user).active.order(updated_at: :desc).detect { |s| s.active_at?(at: at) }
    end

    # Returns the active insight-triggered trial grant if present.
    #
    # @return [Billing::EntitlementGrant, nil]
    def insight_trial_grant
      @insight_trial_grant ||= Billing::EntitlementGrant
        .where(user: user, source: "trial", reason: "insight_triggered")
        .active_at(at)
        .first
    end

    # @return [Boolean]
    def insight_trial_active?
      insight_trial_grant.present?
    end

    # @return [Time, nil]
    def insight_trial_expires_at
      insight_trial_grant&.expires_at
    end

    # Returns the time remaining in the insight trial in seconds.
    #
    # @return [Integer, nil]
    def insight_trial_time_remaining
      return nil unless insight_trial_active?
      [ (insight_trial_expires_at - Time.current).to_i, 0 ].max
    end

    # Returns a human-readable time remaining string.
    #
    # @return [String, nil]
    def insight_trial_time_remaining_in_words
      seconds = insight_trial_time_remaining
      return nil if seconds.nil?

      hours = seconds / 3600
      minutes = (seconds % 3600) / 60

      if hours > 0
        "#{hours} hour#{'s' if hours != 1}"
      elsif minutes > 0
        "#{minutes} minute#{'s' if minutes != 1}"
      else
        "less than a minute"
      end
    end

    # Returns the overall subscription status.
    #
    # @return [Symbol] :trial, :free, :active, :trialing, :cancelled, :past_due, :expired, :inactive
    def subscription_status
      return :trial if insight_trial_active? && active_subscription.nil?
      return :free if active_subscription.nil?
      active_subscription.status.to_sym
    end

    # Returns the next billing/renewal date.
    #
    # @return [Time, nil]
    def renewal_date
      active_subscription&.current_period_ends_at
    end

    # Returns whether the subscription is set to cancel at period end.
    #
    # @return [Boolean]
    def cancel_at_period_end?
      active_subscription&.cancel_at_period_end || false
    end

    # Returns usage data for all quota features.
    #
    # @return [Hash] { feature_key => { used: X, limit: Y, remaining: Z, name: String } }
    def quota_usage
      quota_features = Billing::Feature.where(kind: "quota")

      quota_features.each_with_object({}) do |feature, hash|
        lim = limit(feature.key)
        used = usage_for(feature.key)
        hash[feature.key] = {
          name: feature.name,
          used: used,
          limit: lim,
          remaining: lim.nil? ? nil : [ lim - used, 0 ].max,
          unlimited: lim.nil?
        }
      end
    end

    private

    def entitlement_spec(feature_key)
      key = feature_key.to_s

      merged = plan_entitlements_hash
      grants = active_grants

      # Grants override plan entitlements
      grants.each do |grant|
        grant.entitlements.each do |k, v|
          merged[k.to_s] = (merged[k.to_s] || {}).merge(v || {})
        end
      end

      merged[key] || {}
    end

    def plan_entitlements_hash
      p = plan
      return {} if p.nil?

      p.plan_entitlements.includes(:feature).each_with_object({}) do |ent, h|
        next if ent.feature.nil?

        h[ent.feature.key] = {
          "enabled" => ent.enabled == true,
          "limit" => ent.limit
        }.compact
      end
    end

    def active_grants
      Billing::EntitlementGrant.active_at(at).where(user: user).order(created_at: :asc).to_a
    end

    def usage_for(feature_key)
      period = usage_period
      counter = Billing::UsageCounter.find_by(
        user: user,
        feature_key: feature_key.to_s,
        period_starts_at: period[:starts_at]
      )
      counter&.used.to_i
    end

    # For v1 we use a simple calendar-month usage window.
    # (We can evolve this later to support per-plan windows or Sprint-style 30-day windows.)
    def usage_period
      starts_at = at.beginning_of_month
      ends_at = (starts_at + 1.month)
      { starts_at: starts_at, ends_at: ends_at }
    end
  end
end
