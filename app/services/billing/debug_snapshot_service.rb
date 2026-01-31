# frozen_string_literal: true

module Billing
  # Builds a debug snapshot of billing/subscription state for a user.
  # Intended for internal support/debug UI (developer portal).
  #
  # @example
  #   snapshot = Billing::DebugSnapshotService.new(user: Current.user).run
  #
  class DebugSnapshotService
    # @param user [User]
    # @param at [Time]
    def initialize(user:, at: Time.current)
      @user = user
      @at = at
    end

    # @return [Hash]
    def run
      ent = Billing::Entitlements.for(user, at: at)
      subscription = ent.active_subscription
      grants = Billing::EntitlementGrant.active_at(at).where(user: user).order(created_at: :asc).to_a

      {
        generated_at: at.iso8601,
        user: {
          id: user.id,
          uuid: user.uuid,
          email: user.email_address,
          legacy_is_admin_flag: (user.respond_to?(:is_admin) ? (user.is_admin == true) : nil)
        },
        plans: {
          subscription_plan: plan_summary(ent.subscription_plan),
          effective_plan: plan_summary(ent.effective_plan)
        },
        subscription: subscription_summary(subscription),
        grants: grants.map { |g| grant_summary(g) },
        entitlements: entitlements_summary(ent)
      }
    end

    private

    attr_reader :user, :at

    # @param plan [Billing::Plan, nil]
    # @return [Hash, nil]
    def plan_summary(plan)
      return nil if plan.nil?

      {
        id: plan.id,
        uuid: plan.uuid,
        key: plan.key,
        name: plan.name,
        plan_type: plan.plan_type,
        interval: plan.interval,
        amount_cents: plan.amount_cents,
        currency: plan.currency,
        published: plan.published
      }
    end

    # @param subscription [Billing::Subscription, nil]
    # @return [Hash, nil]
    def subscription_summary(subscription)
      return nil if subscription.nil?

      {
        id: subscription.id,
        uuid: subscription.uuid,
        provider: subscription.provider,
        status: subscription.status,
        plan: plan_summary(subscription.plan),
        current_period_starts_at: subscription.current_period_starts_at&.iso8601,
        current_period_ends_at: subscription.current_period_ends_at&.iso8601,
        trial_ends_at: subscription.trial_ends_at&.iso8601,
        cancel_at_period_end: subscription.cancel_at_period_end,
        updated_at: subscription.updated_at&.iso8601
      }
    end

    # @param grant [Billing::EntitlementGrant]
    # @return [Hash]
    def grant_summary(grant)
      entitlement_keys = grant.entitlements.is_a?(Hash) ? grant.entitlements.keys.sort : []

      {
        id: grant.id,
        uuid: grant.uuid,
        source: grant.source,
        reason: grant.reason,
        plan: plan_summary(grant.plan),
        starts_at: grant.starts_at&.iso8601,
        expires_at: grant.expires_at&.iso8601,
        active: grant.active?(time: at),
        entitlements_keys: entitlement_keys,
        entitlements_size: grant.entitlements.is_a?(Hash) ? grant.entitlements.size : nil,
        entitlements_sample: entitlements_sample(grant.entitlements)
      }
    end

    # @param entitlements [Object]
    # @return [Hash]
    def entitlements_sample(entitlements)
      return {} unless entitlements.is_a?(Hash)

      keys = %w[
        interview_prepare_access
        interview_prepare_refreshes
        round_prep_access
        round_prep_generations
        ai_summaries
        interviews
      ]

      entitlements.slice(*keys)
    end

    # @param ent [Billing::Entitlements]
    # @return [Hash]
    def entitlements_summary(ent)
      feature_keys = %w[
        interview_prepare_access
        interview_prepare_refreshes
        round_prep_access
        round_prep_generations
        ai_summaries
        interviews
      ]

      {
        subscription_status: ent.subscription_status,
        purchase_active: ent.purchase_active?,
        purchase_expires_at: ent.purchase_expires_at&.iso8601,
        insight_trial_active: ent.insight_trial_active?,
        insight_trial_expires_at: ent.insight_trial_expires_at&.iso8601,
        billing_admin_access: user.billing_admin_access?,
        features: feature_keys.index_with { |k| feature_debug(ent, k) }
      }
    end

    # @param ent [Billing::Entitlements]
    # @param feature_key [String]
    # @return [Hash]
    def feature_debug(ent, feature_key)
      feature = Billing::Feature.find_by(key: feature_key)
      kind = feature&.kind || "unknown"

      limit = ent.limit(feature_key)
      remaining = ent.remaining(feature_key)

      {
        kind: kind,
        allowed: ent.allowed?(feature_key),
        limit: limit,
        remaining: remaining,
        used_this_period: used_this_period(feature_key, limit: limit, remaining: remaining)
      }.compact
    end

    # @param feature_key [String]
    # @param limit [Integer, nil]
    # @param remaining [Integer, nil]
    # @return [Integer, nil]
    def used_this_period(feature_key, limit:, remaining:)
      return nil if limit.nil? || remaining.nil?
      limit - remaining
    end
  end
end
