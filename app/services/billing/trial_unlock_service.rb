# frozen_string_literal: true

module Billing
  # Service for unlocking an insight-triggered Pro trial for a user.
  #
  # This is provider-agnostic and implemented via Billing::EntitlementGrant
  # so it works with LemonSqueezy today and other providers later.
  #
  # Eligibility:
  # - Once per user lifetime
  # - Only if user is not already on an active paid subscription
  #
  # @example
  #   result = Billing::TrialUnlockService.new(user: Current.user, trigger: :first_feedback_after_cv).run
  #   result[:unlocked] # => true/false
  class TrialUnlockService < ApplicationService
    TRIAL_DURATION = 72.hours

    REASON = "insight_triggered"
    SOURCE = "trial"

    # Feature keys granted during the trial (cost-bounded).
    # These keys are used by Billing::Entitlements and can be backed by catalog
    # features later (developer portal managed).
    TRIAL_ENTITLEMENTS = {
      "cv_full_analysis" => { "enabled" => true },
      "feedback_synthesis_advanced" => { "enabled" => true },
      "pattern_detection" => { "enabled" => true },
      "assistant_access" => { "enabled" => true },
      "interview_prepare_access" => { "enabled" => true },
      "round_prep_access" => { "enabled" => true },
      # Quotas (absolute caps) to control AI spend during trial
      "ai_summaries" => { "enabled" => true, "limit" => 25 },
      "interview_prepare_refreshes" => { "enabled" => true, "limit" => 10 },
      "round_prep_generations" => { "enabled" => true, "limit" => 10 },
      "assistant_messages" => { "enabled" => true, "limit" => 50 }
    }.freeze

    # @param user [User]
    # @param trigger [Symbol, String] the trigger event name
    # @param metadata [Hash] optional metadata (e.g., counts, ids)
    def initialize(user:, trigger:, metadata: {})
      @user = user
      @trigger = trigger.to_s
      @metadata = metadata || {}
    end

    # Attempts to unlock the trial.
    #
    # @return [Hash] result hash: { unlocked: Boolean, grant: Billing::EntitlementGrant|nil, expires_at: Time|nil }
    def run
      return { unlocked: false, grant: nil, expires_at: nil } if user.nil?
      return { unlocked: false, grant: nil, expires_at: nil } if ineligible_due_to_subscription?

      Billing::EntitlementGrant.transaction do
        return { unlocked: false, grant: nil, expires_at: nil } if already_unlocked?

        now = Time.current
        grant = Billing::EntitlementGrant.create!(
          user: user,
          source: SOURCE,
          reason: REASON,
          starts_at: now,
          expires_at: now + TRIAL_DURATION,
          entitlements: TRIAL_ENTITLEMENTS,
          metadata: metadata.merge(trigger: trigger)
        )

        { unlocked: true, grant: grant, expires_at: grant.expires_at }
      end
    rescue => e
      notify_error(
        e,
        context: "payment",
        severity: "error",
        user: user,
        trigger: trigger,
        metadata: metadata
      )
      { unlocked: false, grant: nil, expires_at: nil }
    end

    private

    attr_reader :user, :trigger, :metadata

    def already_unlocked?
      Billing::EntitlementGrant.where(user: user, source: SOURCE, reason: REASON).exists?
    end

    def ineligible_due_to_subscription?
      Billing::Subscription.where(user: user).active.any? { |s| s.active_at?(at: Time.current) }
    end
  end
end
