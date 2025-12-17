# frozen_string_literal: true

# InterviewApplication model representing a job application tracking entry
class InterviewApplication < ApplicationRecord
  include Transitionable
  extend FriendlyId
  friendly_id :uuid, use: [ :slugged, :finders ]

  STATUSES = [ :active, :archived, :rejected, :accepted ].freeze
  PIPELINE_STAGES = [ :applied, :screening, :interviewing, :offer, :closed ].freeze

  belongs_to :user
  belongs_to :job_listing, optional: true
  belongs_to :company
  belongs_to :job_role

  has_many :interview_rounds, dependent: :destroy, foreign_key: :interview_application_id
  has_many :application_skill_tags, dependent: :destroy, foreign_key: :interview_id
  has_many :skill_tags, through: :application_skill_tags
  has_one :company_feedback, dependent: :destroy, foreign_key: :interview_application_id
  has_many :synced_emails, dependent: :nullify
  has_one :opportunity, dependent: :nullify
  has_one :fit_assessment, as: :fittable, dependent: :destroy

  validates :user, presence: true
  validates :company, presence: true
  validates :job_role, presence: true

  # Status state machine
  aasm column: :status, with_klass: BaseAasm do
    requires_guards!
    log_transitions!

    state :active, initial: true
    state :archived
    state :rejected
    state :accepted

    event :archive do
      transitions from: :active, to: :archived
    end

    event :reject do
      transitions from: :active, to: :rejected
    end

    event :accept do
      transitions from: :active, to: :accepted
    end

    event :reactivate do
      transitions from: [ :archived, :rejected, :accepted ], to: :active
    end
  end

  # Pipeline stage state machine
  aasm :pipeline_stage, column: :pipeline_stage, with_klass: BaseAasm do
    requires_guards!
    log_transitions!

    state :applied, initial: true
    state :screening
    state :interviewing
    state :offer
    state :closed

    event :move_to_screening do
      transitions from: [ :applied, :interviewing ], to: :screening
    end

    event :move_to_interviewing do
      transitions from: [ :applied, :screening, :offer ], to: :interviewing
    end

    event :move_to_offer do
      transitions from: [ :screening, :interviewing ], to: :offer
    end

    event :move_to_closed do
      transitions from: [ :applied, :screening, :interviewing, :offer ], to: :closed
    end

    event :move_to_applied do
      transitions from: [ :screening, :interviewing ], to: :applied
    end
  end

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_pipeline_stage, ->(stage) { where(pipeline_stage: stage) }
  scope :with_active_rounds, -> { joins(:interview_rounds).where(interview_rounds: { result: :pending }).distinct }

  before_create :set_uuid
  before_create :set_applied_at

  # Returns a short summary for display in cards
  # @return [String] Summary text
  def card_summary
    ai_summary.presence || "#{display_company.name} - #{display_job_role.title}"
  end

  # Returns the best available company for display
  #
  # Prefers the job_listing's company when extraction has completed and
  # produced a non-placeholder result. Falls back to the application's
  # own company association.
  #
  # @return [Company] The company to display
  def display_company
    # If we have a job listing with extraction completed and valid company, use it
    if job_listing&.extraction_completed? && job_listing.company.present?
      jl_company = job_listing.company
      # Prefer job_listing's company unless it's also a placeholder
      unless placeholder_company?(jl_company)
        return jl_company
      end
    end

    # Fall back to application's own company
    company
  end

  # Returns the best available job role for display
  #
  # @return [JobRole] The job role to display
  def display_job_role
    # If we have a job listing with extraction completed and valid job role, use it
    if job_listing&.extraction_completed? && job_listing.job_role.present?
      jl_role = job_listing.job_role
      unless placeholder_job_role?(jl_role)
        return jl_role
      end
    end

    # Fall back to application's own job role
    job_role
  end

  # Checks if this application has any interview rounds
  # @return [Boolean] True if rounds exist
  def has_rounds?
    interview_rounds.exists?
  end

  # Returns the most recent interview round
  # @return [InterviewRound, nil] Most recent round or nil
  def latest_round
    interview_rounds.ordered.last
  end

  # Returns count of completed rounds
  # @return [Integer] Count of completed rounds
  def completed_rounds_count
    interview_rounds.completed.count
  end

  # Returns count of total rounds
  # @return [Integer] Total count of rounds
  def total_rounds_count
    interview_rounds.count
  end

  # Checks if application has company feedback
  # @return [Boolean] True if company feedback exists
  def has_company_feedback?
    company_feedback.present?
  end

  # Returns count of pending rounds
  # @return [Integer] Count of pending rounds
  def pending_rounds_count
    interview_rounds.where(result: :pending).count
  end

  # Returns badge color for status
  # @return [String] Color name for badge
  def status_badge_color
    case status.to_sym
    when :active then "blue"
    when :accepted then "green"
    when :rejected then "red"
    when :archived then "gray"
    else "gray"
    end
  end

  # Returns formatted pipeline stage name
  # @return [String] Formatted stage name
  def pipeline_stage_display
    pipeline_stage.to_s.titleize
  end

  private

  PLACEHOLDER_COMPANY_NAMES = [ "unknown company", "unknown" ].freeze
  PLACEHOLDER_JOB_ROLES = [ "unknown position", "unknown role", "unknown" ].freeze

  def placeholder_company?(comp)
    return true if comp.nil?
    PLACEHOLDER_COMPANY_NAMES.any? { |p| comp.name&.downcase&.include?(p) }
  end

  def placeholder_job_role?(role)
    return true if role.nil?
    PLACEHOLDER_JOB_ROLES.any? { |p| role.title&.downcase&.include?(p) }
  end

  def set_uuid
    self.uuid = SecureRandom.uuid
  end

  def set_applied_at
    self.applied_at = Time.current if applied_at.blank?
  end
end
