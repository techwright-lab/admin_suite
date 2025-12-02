# frozen_string_literal: true

# InterviewRound model representing individual interview rounds in an application process
class InterviewRound < ApplicationRecord
  STAGES = [ :screening, :technical, :hiring_manager, :culture_fit, :other ].freeze
  RESULTS = [ :pending, :passed, :failed, :waitlisted ].freeze

  belongs_to :interview_application
  has_one :interview_feedback, dependent: :destroy

  enum :stage, STAGES, default: :screening
  enum :result, RESULTS, default: :pending

  validates :interview_application, presence: true
  validates :stage, presence: true, inclusion: { in: STAGES.map(&:to_s) }
  validates :result, inclusion: { in: RESULTS.map(&:to_s) }

  scope :by_stage, ->(stage) { where(stage: stage) }
  scope :completed, -> { where.not(completed_at: nil) }
  scope :upcoming, -> { where(completed_at: nil).where("scheduled_at > ?", Time.current) }
  scope :ordered, -> { order(position: :asc, scheduled_at: :asc, created_at: :asc) }

  # Returns display name for the stage
  # @return [String] Stage display name
  def stage_display_name
    stage_name.presence || stage.to_s.humanize
  end

  # Alias for stage_display_name for consistency
  alias_method :stage_display, :stage_display_name

  # Checks if round is completed
  # @return [Boolean] True if completed
  def completed?
    completed_at.present?
  end

  # Checks if round is upcoming
  # @return [Boolean] True if upcoming
  def upcoming?
    scheduled_at.present? && scheduled_at > Time.current && !completed?
  end

  # Returns duration in hours and minutes
  # @return [String, nil] Formatted duration
  def formatted_duration
    return nil if duration_minutes.nil?

    hours = duration_minutes / 60
    minutes = duration_minutes % 60

    if hours > 0 && minutes > 0
      "#{hours}h #{minutes}m"
    elsif hours > 0
      "#{hours}h 0m"
    else
      "#{minutes}m"
    end
  end

  # Returns badge color for result
  # @return [String] Color name for badge
  def result_badge_color
    case result.to_sym
    when :pending then "yellow"
    when :passed then "green"
    when :failed then "red"
    when :waitlisted then "blue"
    else "gray"
    end
  end

  # Returns formatted interviewer information
  # @return [String, nil] Formatted interviewer info
  def interviewer_display
    return nil if interviewer_name.blank?
    return interviewer_name if interviewer_role.blank?

    "#{interviewer_name} (#{interviewer_role})"
  end
end
