# frozen_string_literal: true

# Opportunity model for tracking recruiter outreach emails
# Captures job opportunities from emails before user decides to apply
#
# @example
#   opportunity = Opportunity.create!(user: user, company_name: "Stripe")
#   opportunity.apply! # Transitions to applied state
#
class Opportunity < ApplicationRecord
  include Transitionable

  # Status values stored as strings for readability
  STATUSES = %i[new reviewing applied archived].freeze
  SOURCE_TYPES = %w[direct_email linkedin_forward referral other].freeze

  # Associations
  belongs_to :user
  belongs_to :synced_email, optional: true
  belongs_to :interview_application, optional: true
  belongs_to :job_listing, optional: true
  has_one :saved_job, dependent: :destroy
  has_one :fit_assessment, as: :fittable, dependent: :destroy

  # Validations
  validates :user, presence: true
  validates :source_type, inclusion: { in: SOURCE_TYPES }, allow_nil: true

  # Store accessors for extracted_data
  store_accessor :extracted_data,
    :is_forwarded,
    :original_source,
    :raw_extraction

  # AASM state machine for status
  aasm column: :status, with_klass: BaseAasm do
    requires_guards!
    log_transitions!

    state :new, initial: true
    state :reviewing
    state :applied
    state :archived

    event :start_review do
      transitions from: :new, to: :reviewing
    end

    event :mark_applied do
      transitions from: [ :new, :reviewing ], to: :applied
    end

    event :archive_as_ignored do
      transitions from: [ :new, :reviewing ], to: :archived, after: :set_archived_as_ignored
    end

    event :reconsider do
      transitions from: :archived, to: :new, after: :clear_archived_metadata
    end
  end

  # Scopes
  scope :actionable, -> { where(status: %w[new reviewing]) }
  scope :archived, -> { where(status: "archived") }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :with_job_url, -> { where.not(job_url: [ nil, "" ]) }
  scope :without_job_url, -> { where(job_url: [ nil, "" ]) }

  # Returns the display title for this opportunity
  #
  # @return [String] Title combining role and company
  def display_title
    parts = []
    parts << job_role_title if job_role_title.present?
    parts << "at #{company_name}" if company_name.present?
    parts.join(" ") || "New Opportunity"
  end

  # Returns the recruiter display name
  #
  # @return [String, nil] Recruiter name or email
  def recruiter_display
    recruiter_name.presence || recruiter_email
  end

  # Checks if this opportunity has a job URL
  #
  # @return [Boolean] True if job_url is present
  def has_job_url?
    job_url.present?
  end

  # Checks if this opportunity has extracted links
  #
  # @return [Boolean] True if extracted_links is not empty
  def has_extracted_links?
    extracted_links.present? && extracted_links.any?
  end

  # Returns extracted links as structured objects
  #
  # @return [Array<Hash>] Array of link hashes with url, type, description
  def parsed_links
    return [] unless extracted_links.is_a?(Array)

    extracted_links.map do |link|
      if link.is_a?(Hash)
        link.symbolize_keys
      else
        { url: link.to_s, type: "unknown", description: nil }
      end
    end
  end

  # Returns the primary job link (first job-related link found)
  #
  # @return [String, nil] The primary job URL
  def primary_job_link
    return job_url if job_url.present?

    job_link = parsed_links.find { |l| l[:type] == "job_posting" }
    job_link&.dig(:url)
  end

  # Checks if this is a forwarded email (e.g., from LinkedIn)
  #
  # @return [Boolean] True if the email was forwarded
  def forwarded?
    is_forwarded == true || source_type == "linkedin_forward"
  end

  # Returns badge classes for the status
  #
  # @return [String] Tailwind CSS classes
  def status_badge_classes
    case status
    when "new"
      "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300"
    when "reviewing"
      "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300"
    when "applied"
      "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300"
    when "archived"
      "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
    else
      "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
    end
  end

  # Returns icon name for source type
  #
  # @return [String] Icon identifier
  def source_type_icon
    case source_type
    when "linkedin_forward"
      "linkedin"
    when "referral"
      "users"
    when "direct_email"
      "mail"
    else
      "mail"
    end
  end

  # Returns human-readable source type
  #
  # @return [String] Display name
  def source_type_display
    case source_type
    when "linkedin_forward"
      "LinkedIn"
    when "referral"
      "Referral"
    when "direct_email"
      "Direct Email"
    else
      "Email"
    end
  end

  # Returns a short snippet for display
  #
  # @param length [Integer] Maximum length
  # @return [String] Truncated key details or email snippet
  def short_description(length = 100)
    text = key_details.presence || email_snippet
    text&.truncate(length) || ""
  end

  private

  # @return [void]
  def set_archived_as_ignored
    update_columns(
      archived_reason: "ignored",
      archived_at: Time.current
    )
  end

  # @return [void]
  def clear_archived_metadata
    update_columns(
      archived_reason: nil,
      archived_at: nil
    )
  end
end
