# frozen_string_literal: true

# Generates and caches interview prep artifacts for an application.
#
# Enforces quota usage once per pack refresh (monthly window via Billing::UsageCounter).
class GenerateInterviewPrepPackJob < ApplicationJob
  queue_as :default

  # @param interview_application [InterviewApplication]
  # @param user [User]
  def perform(interview_application, user:)
    ent = Billing::Entitlements.for(user)
    return unless ent.allowed?(:interview_prepare_access)

    remaining = ent.remaining(:interview_prepare_refreshes)
    return if remaining.is_a?(Integer) && remaining <= 0

    period = {
      starts_at: Time.current.beginning_of_month,
      ends_at: (Time.current.beginning_of_month + 1.month)
    }

    Billing::UsageCounter.increment!(
      user: user,
      feature_key: "interview_prepare_refreshes",
      period_starts_at: period[:starts_at],
      period_ends_at: period[:ends_at],
      delta: 1
    )

    InterviewPrep::GenerateMatchAnalysisService.new(user: user, interview_application: interview_application).call
    InterviewPrep::GenerateFocusAreasService.new(user: user, interview_application: interview_application).call
    InterviewPrep::GenerateQuestionFramingService.new(user: user, interview_application: interview_application).call
    InterviewPrep::GenerateStrengthPositioningService.new(user: user, interview_application: interview_application).call
  end
end
