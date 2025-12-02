# frozen_string_literal: true

# InterviewFeedback model representing self-reflection and notes for an interview round
class InterviewFeedback < ApplicationRecord
  self.table_name = "interview_feedbacks"
  
  belongs_to :interview_round

  serialize :tags, coder: JSON

  attribute :tags, default: -> { [] }

  validates :interview_round, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :with_recommendations, -> { where.not(recommended_action: nil) }

  # Returns tags as an array
  # @return [Array<String>] Array of tag strings
  def tag_list
    Array.wrap(tags)
  end

  # Sets tags from an array or comma-separated string
  # @param value [Array, String] Tags to set
  def tag_list=(value)
    self.tags = if value.is_a?(String)
      value.split(",").map(&:strip).reject(&:blank?)
    else
      Array.wrap(value)
    end
  end

  # Checks if this feedback has an AI summary
  # @return [Boolean] True if AI summary exists
  def has_ai_summary?
    ai_summary.present?
  end

  # Returns a short summary of what went well
  # @return [String] Truncated summary
  def summary_preview
    went_well.presence&.truncate(100) || "No feedback yet"
  end
end

