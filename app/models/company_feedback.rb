# frozen_string_literal: true

# CompanyFeedback model representing overall feedback from company for entire application process
class CompanyFeedback < ApplicationRecord
  belongs_to :interview_application

  validates :interview_application, presence: true

  scope :recent, -> { order(received_at: :desc, created_at: :desc) }
  scope :with_rejection, -> { where.not(rejection_reason: nil) }

  # Checks if this is a rejection feedback
  # @return [Boolean] True if rejection reason exists
  def rejection?
    rejection_reason.present?
  end

  # Checks if feedback has been received
  # @return [Boolean] True if received_at is set
  def received?
    received_at.present?
  end

  # Returns a summary of the feedback
  # @return [String] Feedback summary
  def summary
    feedback_text.presence || "No feedback yet"
  end

  # Checks if feedback has next steps
  # @return [Boolean] True if next steps exist
  def has_next_steps?
    next_steps.present?
  end

  # Returns sentiment of the feedback
  # @return [String] Sentiment (positive, negative, neutral)
  def sentiment
    return "negative" if rejection?
    return "positive" if has_next_steps?
    "neutral"
  end
end
