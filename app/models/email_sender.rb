# frozen_string_literal: true

# EmailSender model for tracking unique email addresses and associating them with companies
# This helps build a contacts database for interview-related communications
#
# @example
#   sender = EmailSender.find_or_create_from_email("recruiter@company.com", "Jane Doe")
#   sender.assign_company!(company)
#
class EmailSender < ApplicationRecord
  SENDER_TYPES = %w[recruiter hiring_manager hr ats_system unknown].freeze

  belongs_to :company, optional: true
  belongs_to :auto_detected_company, class_name: "Company", optional: true

  has_many :synced_emails, dependent: :nullify

  # Validations
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :domain, presence: true
  validates :sender_type, inclusion: { in: SENDER_TYPES }, allow_nil: true

  # Normalizations
  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :domain, with: ->(domain) { domain.strip.downcase }

  # Scopes
  scope :unassigned, -> { where(company_id: nil) }
  scope :assigned, -> { where.not(company_id: nil) }
  scope :verified, -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }
  scope :auto_detected, -> { where.not(auto_detected_company_id: nil).where(company_id: nil) }
  scope :by_domain, ->(domain) { where(domain: domain.downcase) }
  scope :recent, -> { order(last_seen_at: :desc) }
  scope :most_active, -> { order(email_count: :desc) }
  scope :alphabetical, -> { order(:email) }

  # Callbacks
  before_validation :extract_domain, if: -> { email.present? && domain.blank? }
  before_validation :detect_sender_type, if: -> { sender_type.blank? }

  # Finds or creates an EmailSender from an email address
  #
  # @param email [String] The email address
  # @param name [String, nil] The sender's display name
  # @return [EmailSender]
  def self.find_or_create_from_email(email, name = nil)
    return nil if email.blank?

    sender = find_or_initialize_by(email: email.strip.downcase)
    sender.name = name if name.present? && sender.name.blank?
    sender.last_seen_at = Time.current
    sender.email_count = (sender.email_count || 0) + 1 unless sender.new_record?
    sender.save!
    sender
  rescue ActiveRecord::RecordNotUnique
    # Handle race condition
    find_by!(email: email.strip.downcase)
  end

  # Increments the email count and updates last seen timestamp
  #
  # @return [Boolean]
  def record_email!
    increment!(:email_count)
    update!(last_seen_at: Time.current)
  end

  # Assigns a company to this sender (admin action)
  #
  # @param company [Company] The company to assign
  # @param verify [Boolean] Whether to mark as verified
  # @return [Boolean]
  def assign_company!(company, verify: true)
    update!(company: company, verified: verify)
  end

  # Returns the effective company (admin-assigned or auto-detected)
  #
  # @return [Company, nil]
  def effective_company
    company || auto_detected_company
  end

  # Checks if this sender has a company assigned
  #
  # @return [Boolean]
  def has_company?
    company_id.present? || auto_detected_company_id.present?
  end

  # Checks if this is from an ATS system
  #
  # @return [Boolean]
  def ats_system?
    sender_type == "ats_system"
  end

  # Returns a display name for the sender
  #
  # @return [String]
  def display_name
    name.presence || email
  end

  private

  # Extracts domain from email address
  #
  # @return [void]
  def extract_domain
    return unless email.present?

    self.domain = email.split("@").last&.downcase
  end

  # Detects sender type based on email patterns
  #
  # @return [void]
  def detect_sender_type
    return unless domain.present?

    self.sender_type = if ats_domain?
                         "ats_system"
                       elsif recruiter_pattern?
                         "recruiter"
                       elsif hr_pattern?
                         "hr"
                       else
                         "unknown"
                       end
  end

  # Checks if domain is from a known ATS system
  #
  # @return [Boolean]
  def ats_domain?
    Gmail::SyncService::RECRUITER_DOMAINS.any? { |d| domain.include?(d) }
  end

  # Checks if email matches recruiter patterns
  #
  # @return [Boolean]
  def recruiter_pattern?
    email.match?(/recruit|talent|sourcing/i)
  end

  # Checks if email matches HR patterns
  #
  # @return [Boolean]
  def hr_pattern?
    email.match?(/\bhr\b|human.?resources|people.?ops/i)
  end
end

