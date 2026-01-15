# frozen_string_literal: true

# CompanyFeedback model representing overall feedback from company for entire application process
class CompanyFeedback < ApplicationRecord
  FEEDBACK_TYPES = %w[rejection offer general withdrawal on_hold].freeze

  belongs_to :interview_application
  belongs_to :source_email, class_name: "SyncedEmail", optional: true, foreign_key: :source_email_id

  validates :interview_application, presence: true

  scope :recent, -> { order(received_at: :desc, created_at: :desc) }
  scope :with_rejection, -> { where.not(rejection_reason: nil) }
  scope :by_type, ->(type) { where(feedback_type: type) }

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

  # Checks if this feedback is from an email
  # @return [Boolean] True if from email
  def from_email?
    source_email_id.present?
  end

  # Returns friendly feedback type name
  # @return [String] Feedback type display name
  def feedback_type_display
    case feedback_type
    when "rejection" then "Rejection"
    when "offer" then "Job Offer"
    when "general" then "General Feedback"
    when "withdrawal" then "Position Withdrawn"
    when "on_hold" then "On Hold"
    else feedback_type&.titleize || "Unknown"
    end
  end

  # Checks if this is an offer feedback
  # @return [Boolean] True if offer
  def offer?
    feedback_type == "offer"
  end
end
