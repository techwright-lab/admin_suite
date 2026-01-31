# frozen_string_literal: true

# InterviewApplication model representing a job application tracking entry
class InterviewApplication < ApplicationRecord
  include Transitionable
  extend FriendlyId
  friendly_id :uuid, use: [ :slugged, :finders ]

  STATUSES = [ :active, :archived, :rejected, :accepted, :on_hold, :withdrawn ].freeze
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
  has_many :interview_prep_artifacts, dependent: :destroy

  validates :user, presence: true
  validates :company, presence: true
  validates :job_role, presence: true

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  # Status state machine
  aasm column: :status, with_klass: BaseAasm do
    requires_guards!
    log_transitions!

    state :active, initial: true
    state :archived
    state :rejected
    state :accepted
    state :on_hold
    state :withdrawn

    event :archive do
      transitions from: :active, to: :archived
    end

    event :reject do
      transitions from: :active, to: :rejected
    end

    event :accept do
      transitions from: :active, to: :accepted
    end

    event :hold do
      transitions from: :active, to: :on_hold
    end

    event :withdraw do
      transitions from: :active, to: :withdrawn
    end

    event :reactivate do
      transitions from: [ :archived, :rejected, :accepted, :on_hold, :withdrawn ], to: :active
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

  # Set uuid early so FriendlyId can use it for slug generation
  # (FriendlyId runs in before_validation, before before_create)
  before_validation :set_uuid, on: :create
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
    when :on_hold then "yellow"
    when :withdrawn then "gray"
    else "gray"
    end
  end

  # Returns formatted pipeline stage name
  # @return [String] Formatted stage name
  def pipeline_stage_display
    pipeline_stage.to_s.titleize
  end

  # @return [Boolean] Whether this application is soft-deleted.
  def deleted?
    deleted_at.present?
  end

  # Soft delete (move to trash). This does not destroy dependent records.
  #
  # @return [Boolean] true if persisted successfully
  def soft_delete!
    return false if deleted?

    # Use update_columns to avoid triggering FriendlyId/AASM callbacks that may
    # regenerate slugs or block persistence for unrelated reasons.
    update_columns(deleted_at: Time.current, updated_at: Time.current)
  end

  # Restore a soft-deleted application.
  #
  # @return [Boolean] true if persisted successfully
  def restore!
    return false unless deleted?

    update_columns(deleted_at: nil, updated_at: Time.current)
  end

  # Returns a scheduling link from synced emails if available
  # Prioritizes links from scheduling-type emails or high-priority action links
  #
  # @return [Hash, nil] { url: String, platform: String } or nil
  def scheduling_link
    @scheduling_link ||= find_scheduling_link_from_emails
  end

  # Checks if this application has a scheduling link available
  #
  # @return [Boolean] True if scheduling link exists
  def has_scheduling_link?
    scheduling_link.present?
  end

  # Checks if the next interview needs to be scheduled
  # True if no upcoming rounds exist
  #
  # @return [Boolean] True if interview not yet scheduled
  def needs_scheduling?
    interview_rounds.upcoming.none?
  end

  # Returns scheduling link only if interview needs scheduling
  #
  # @return [Hash, nil] { url: String, platform: String } or nil
  def actionable_scheduling_link
    return nil unless needs_scheduling?
    scheduling_link
  end

  private

  # Finds scheduling link from synced emails
  #
  # @return [Hash, nil]
  def find_scheduling_link_from_emails
    synced_emails.each do |email|
      next unless email.signal_action_links.is_a?(Array)

      # Look for scheduling links (priority 1 or label contains "schedule")
      email.signal_action_links.each do |link|
        if link["priority"] == 1 || link["action_label"]&.downcase&.include?("schedule")
          return {
            url: link["url"],
            platform: extract_platform_name(link["url"]),
            label: link["action_label"]
          }
        end
      end
    end
    nil
  end

  # Extracts friendly platform name from URL
  #
  # @param url [String]
  # @return [String]
  def extract_platform_name(url)
    case url
    when /goodtime\.io/i then "GoodTime"
    when /calendly\.com/i then "Calendly"
    when /cal\.com/i then "Cal.com"
    when /doodle\.com/i then "Doodle"
    when /zoom\.us/i then "Zoom"
    else "scheduling link"
    end
  end

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
