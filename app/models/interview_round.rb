# frozen_string_literal: true

# InterviewRound model representing individual interview rounds in an application process
class InterviewRound < ApplicationRecord
  STAGES = [ :screening, :technical, :hiring_manager, :culture_fit, :other ].freeze
  RESULTS = [ :pending, :passed, :failed, :waitlisted ].freeze
  CONFIRMATION_SOURCES = %w[calendly goodtime greenhouse lever manual other].freeze

  belongs_to :interview_application
  belongs_to :source_email, class_name: "SyncedEmail", optional: true, foreign_key: :source_email_id
  belongs_to :interview_round_type, optional: true
  has_one :interview_feedback, dependent: :destroy
  has_many :prep_artifacts, class_name: "InterviewRoundPrepArtifact", dependent: :destroy

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

  # Checks if round has a video link
  # @return [Boolean] True if video link exists
  def has_video_link?
    video_link.present?
  end

  # Checks if round was created from email
  # @return [Boolean] True if created from email
  def from_email?
    source_email_id.present?
  end

  # Returns friendly confirmation source name
  # @return [String] Confirmation source display name
  def confirmation_source_display
    case confirmation_source
    when "calendly" then "Calendly"
    when "goodtime" then "GoodTime"
    when "greenhouse" then "Greenhouse"
    when "lever" then "Lever"
    when "manual" then "Direct Email"
    else confirmation_source&.titleize || "Unknown"
    end
  end

  # Returns the round type name for display
  # @return [String, nil] Round type name or nil if not set
  def round_type_name
    interview_round_type&.name
  end

  # Returns the round type slug for prep matching
  # @return [String, nil] Round type slug or nil if not set
  def round_type_slug
    interview_round_type&.slug
  end

  # Returns the comprehensive prep artifact if it exists and is completed
  # @return [InterviewRoundPrepArtifact, nil] The prep artifact or nil
  def prep
    prep_artifacts.completed.find_by(kind: :comprehensive)
  end

  # Checks if prep has been generated for this round
  # @return [Boolean] True if prep exists and is completed
  def has_prep?
    prep.present?
  end
end
