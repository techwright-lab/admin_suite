# frozen_string_literal: true

# Generates round-specific interview prep for an interview round.
#
# Uses InterviewRoundPrep::GenerateService to generate tailored preparation
# content based on round type, historical performance, and company patterns.
#
# Enforces quota usage per generation (monthly window via Billing::UsageCounter).
class GenerateRoundPrepJob < ApplicationJob
  queue_as :default

  # @param interview_round [InterviewRound]
  # @param force [Boolean] Force regeneration even if prep exists
  def perform(interview_round, force: false)
    user = interview_round.interview_application.user

    # Check entitlements
    ent = Billing::Entitlements.for(user)
    return unless ent.allowed?(:round_prep_access)

    # Check quota
    remaining = ent.remaining(:round_prep_generations)
    return if remaining.is_a?(Integer) && remaining <= 0

    # Track usage
    period = {
      starts_at: Time.current.beginning_of_month,
      ends_at: (Time.current.beginning_of_month + 1.month)
    }

    Billing::UsageCounter.increment!(
      user: user,
      feature_key: "round_prep_generations",
      period_starts_at: period[:starts_at],
      period_ends_at: period[:ends_at],
      delta: 1
    )

    # Generate the prep
    InterviewRoundPrep::GenerateService.new(
      interview_round: interview_round,
      force: force
    ).call
  rescue StandardError => e
    # Mark artifact as failed
    artifact = InterviewRoundPrepArtifact.find_by(
      interview_round: interview_round,
      kind: :comprehensive
    )
    artifact&.fail!(e.message)

    handle_error(e,
      context: "round_prep_generation",
      user: user,
      interview_round_id: interview_round.id
    )
  end
end
