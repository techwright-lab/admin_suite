# frozen_string_literal: true

# SyncedEmail model for tracking emails synced from Gmail
# Links emails to interview applications and tracks processing status
#
# @example
#   email = SyncedEmail.create_from_gmail_message(user, account, message)
#   email.process!
#
class SyncedEmail < ApplicationRecord
  STATUSES = %i[pending processed ignored failed auto_ignored].freeze
  EMAIL_TYPES = %w[
    application_confirmation
    interview_invite
    interview_reminder
    rejection
    offer
    follow_up
    thank_you
    scheduling
    assessment
    recruiter_outreach
    other
  ].freeze

  # Types that are interview-related
  INTERVIEW_TYPES = %w[
    application_confirmation
    interview_invite
    interview_reminder
    rejection
    offer
    follow_up
    scheduling
    assessment
  ].freeze

  # Types that represent potential opportunities
  OPPORTUNITY_TYPES = %w[recruiter_outreach].freeze

  belongs_to :user
  belongs_to :connected_account
  belongs_to :interview_application, optional: true
  belongs_to :email_sender, optional: true
  has_one :opportunity, dependent: :nullify

  # Status enum
  enum :status, STATUSES, default: :pending

  # Validations
  validates :gmail_id, presence: true, uniqueness: { scope: :user_id }
  validates :from_email, presence: true
  validates :email_type, inclusion: { in: EMAIL_TYPES }, allow_nil: true

  # Normalizations
  normalizes :from_email, with: ->(email) { email.strip.downcase }

  # Scopes
  scope :unmatched, -> { where(interview_application_id: nil) }
  scope :matched, -> { where.not(interview_application_id: nil) }
  scope :by_type, ->(type) { where(email_type: type) }
  scope :recent, -> { order(email_date: :desc) }
  scope :chronological, -> { order(email_date: :asc) }
  scope :by_thread, ->(thread_id) { where(thread_id: thread_id) }
  scope :needs_review, -> { pending.unmatched }
  scope :from_account, ->(account) { where(connected_account: account) }
  scope :for_application, ->(app) { where(interview_application: app) }
  scope :recruiter_outreach, -> { where(email_type: "recruiter_outreach") }

  # Relevance scopes for smart filtering
  scope :interview_related, -> {
    where(email_type: INTERVIEW_TYPES).or(matched)
  }
  scope :potential_opportunities, -> { where(email_type: OPPORTUNITY_TYPES) }
  scope :relevant, -> {
    visible.where(
      "email_type IN (?) OR email_type IN (?) OR interview_application_id IS NOT NULL",
      INTERVIEW_TYPES,
      OPPORTUNITY_TYPES
    )
  }
  scope :not_ignored, -> { where.not(status: :ignored) }
  scope :not_auto_ignored, -> { where.not(status: :auto_ignored) }
  scope :visible, -> { where.not(status: [ :ignored, :auto_ignored ]) }

  # Callbacks
  before_save :link_or_create_sender

  # Store accessors for metadata
  store_accessor :metadata, :to_email, :cc_emails, :reply_to, :importance

  # Creates a SyncedEmail from a parsed Gmail message
  #
  # @param user [User] The user who owns this email
  # @param connected_account [ConnectedAccount] The Gmail account
  # @param message_data [Hash] Parsed email data from Gmail::SyncService
  # @return [SyncedEmail, nil]
  def self.create_from_gmail_message(user, connected_account, message_data)
    return nil if message_data.blank? || message_data[:id].blank?

    # Check if already synced
    existing = find_by(user: user, gmail_id: message_data[:id])
    return existing if existing

    create!(
      user: user,
      connected_account: connected_account,
      gmail_id: message_data[:id],
      thread_id: message_data[:thread_id],
      subject: message_data[:subject],
      from_email: extract_email(message_data[:from]),
      from_name: extract_name(message_data[:from]),
      email_date: message_data[:date],
      snippet: message_data[:snippet],
      body_preview: message_data[:body_preview],
      body_html: message_data[:body_html],
      labels: message_data[:labels] || [],
      status: :pending
    )
  rescue ActiveRecord::RecordNotUnique
    # Handle race condition - email already exists
    find_by(user: user, gmail_id: message_data[:id])
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Failed to create SyncedEmail: #{e.message}"
    nil
  end

  # Extracts email address from "Name <email>" format
  #
  # @param from_string [String] The from header value
  # @return [String]
  def self.extract_email(from_string)
    return "" if from_string.blank?

    match = from_string.match(/<([^>]+)>/)
    match ? match[1].strip.downcase : from_string.strip.downcase
  end

  # Extracts display name from "Name <email>" format
  #
  # @param from_string [String] The from header value
  # @return [String, nil]
  def self.extract_name(from_string)
    return nil if from_string.blank?

    match = from_string.match(/^([^<]+)</)
    match ? match[1].strip.gsub(/"/, "") : nil
  end

  # Marks this email as matched to an application
  #
  # @param application [InterviewApplication] The matched application
  # @return [Boolean]
  def match_to_application!(application)
    update!(
      interview_application: application,
      status: :processed
    )
  end

  # Marks this email as ignored (not interview-related)
  #
  # @return [Boolean]
  def ignore!
    update!(status: :ignored)
  end

  # Marks processing as failed
  #
  # @param reason [String] The failure reason
  # @return [Boolean]
  def mark_failed!(reason = nil)
    update!(
      status: :failed,
      metadata: metadata.merge("failure_reason" => reason)
    )
  end

  # Checks if this email is matched to an application
  #
  # @return [Boolean]
  def matched?
    interview_application_id.present?
  end

  # Returns a short display subject
  #
  # @param length [Integer] Maximum length
  # @return [String]
  def short_subject(length = 50)
    subject&.truncate(length) || "(No subject)"
  end

  # Returns the sender display (name or email)
  #
  # @return [String]
  def sender_display
    from_name.presence || from_email
  end

  # Returns the company associated with this email (via sender or application)
  #
  # @return [Company, nil]
  def company
    interview_application&.company || email_sender&.effective_company
  end

  # Returns CSS classes for email type badge
  #
  # @return [String]
  def type_badge_classes
    case email_type
    when "interview_invite", "scheduling"
      "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300"
    when "offer"
      "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300"
    when "rejection"
      "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300"
    when "application_confirmation"
      "bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-300"
    when "assessment"
      "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300"
    when "recruiter_outreach"
      "bg-indigo-100 text-indigo-800 dark:bg-indigo-900/30 dark:text-indigo-300"
    else
      "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
    end
  end

  # Returns icon name for email type
  #
  # @return [String]
  def type_icon
    case email_type
    when "interview_invite", "scheduling"
      "calendar"
    when "offer"
      "gift"
    when "rejection"
      "x-circle"
    when "application_confirmation"
      "check-circle"
    when "assessment"
      "clipboard-check"
    when "recruiter_outreach"
      "sparkles"
    when "follow_up", "thank_you"
      "mail"
    else
      "mail"
    end
  end

  # Checks if this email is a recruiter outreach
  #
  # @return [Boolean]
  def recruiter_outreach?
    email_type == "recruiter_outreach"
  end

  # Returns all emails in this conversation thread
  # Includes this email, ordered chronologically (oldest first)
  #
  # @return [ActiveRecord::Relation<SyncedEmail>]
  def thread_emails
    return SyncedEmail.where(id: id) if thread_id.blank?

    SyncedEmail.where(user: user, thread_id: thread_id).chronological
  end

  # Returns count of emails in this thread
  #
  # @return [Integer]
  def thread_count
    return 1 if thread_id.blank?

    SyncedEmail.where(user: user, thread_id: thread_id).count
  end

  # Checks if this email is part of a multi-email thread
  #
  # @return [Boolean]
  def has_thread?
    thread_count > 1
  end

  # Returns the first email in this thread (conversation starter)
  #
  # @return [SyncedEmail]
  def thread_root
    return self if thread_id.blank?

    SyncedEmail.where(user: user, thread_id: thread_id).chronological.first || self
  end

  # Returns the most recent email in this thread
  #
  # @return [SyncedEmail]
  def thread_latest
    return self if thread_id.blank?

    SyncedEmail.where(user: user, thread_id: thread_id).recent.first || self
  end

  # Returns a clean subject without Re:/Fwd: prefixes
  #
  # @return [String]
  def clean_subject
    return "(No subject)" if subject.blank?

    subject.gsub(/^(re:|fwd?:)\s*/i, "").strip.presence || "(No subject)"
  end

  # Checks if this email has HTML content
  #
  # @return [Boolean]
  def has_html_body?
    body_html.present?
  end

  # Returns the best available body content for display
  # Prefers plain text for simple display, but HTML is available for rich rendering
  #
  # @return [String]
  def display_body
    body_preview.presence || snippet.presence || ""
  end

  # Returns sanitized HTML body safe for rendering
  # Removes potentially dangerous tags/attributes while preserving formatting
  #
  # @return [String, nil]
  def safe_html_body
    return nil unless body_html.present?

    # Use Rails sanitizer with safe list of tags
    ActionController::Base.helpers.sanitize(
      body_html,
      tags: %w[p br div span a ul ol li strong b em i u h1 h2 h3 h4 h5 h6 blockquote pre code table tr td th thead tbody hr img],
      attributes: %w[href src alt title class style target]
    )
  end

  private

  # Links or creates the email sender record
  #
  # @return [void]
  def link_or_create_sender
    return if email_sender_id.present? || from_email.blank?

    self.email_sender = EmailSender.find_or_create_from_email(from_email, from_name)
  end
end
