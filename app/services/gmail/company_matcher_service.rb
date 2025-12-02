# frozen_string_literal: true

# Service for matching email senders to companies
# Analyzes email domains and content to auto-detect company associations
#
# @example
#   matcher = Gmail::CompanyMatcherService.new
#   company = matcher.find_company_for_email("recruiter@company.com")
#
class Gmail::CompanyMatcherService
  # Known ATS system domains that should be associated with the sending company, not the ATS
  ATS_DOMAINS = Gmail::SyncService::RECRUITER_DOMAINS.freeze

  # Common email provider domains to ignore
  GENERIC_DOMAINS = %w[
    gmail.com yahoo.com hotmail.com outlook.com live.com
    icloud.com me.com mac.com aol.com mail.com
    protonmail.com pm.me tutanota.com zoho.com
    yandex.com gmx.com fastmail.com
  ].freeze

  # Initialize the service
  def initialize
    @domain_cache = {}
  end

  # Finds or auto-detects a company for an email address
  #
  # @param email [String] The email address
  # @param sender_name [String, nil] The sender's display name
  # @return [Company, nil]
  def find_company_for_email(email, sender_name = nil)
    return nil if email.blank?

    domain = extract_domain(email)
    return nil if generic_domain?(domain)

    # Check cache first
    return @domain_cache[domain] if @domain_cache.key?(domain)

    # Try to find company
    company = find_by_domain(domain) ||
              find_by_website(domain) ||
              find_by_name_from_domain(domain) ||
              find_by_sender_name(sender_name)

    @domain_cache[domain] = company
    company
  end

  # Processes an email sender and updates company associations
  #
  # @param email_sender [EmailSender] The sender to process
  # @return [Hash] Result with detected company info
  def process_sender(email_sender)
    return { success: false, error: "No sender provided" } unless email_sender

    company = find_company_for_email(email_sender.email, email_sender.name)

    if company
      email_sender.update!(auto_detected_company: company) unless email_sender.company_id.present?
      { success: true, company: company, auto_detected: true }
    else
      { success: true, company: nil, auto_detected: false }
    end
  rescue StandardError => e
    Rails.logger.warn "CompanyMatcher failed for #{email_sender.email}: #{e.message}"
    { success: false, error: e.message }
  end

  # Bulk processes all unassigned senders
  #
  # @param limit [Integer] Maximum senders to process
  # @return [Hash] Processing statistics
  def process_unassigned_senders(limit: 100)
    senders = EmailSender.unassigned.where(auto_detected_company_id: nil).limit(limit)
    stats = { processed: 0, matched: 0, unmatched: 0, errors: 0 }

    senders.find_each do |sender|
      result = process_sender(sender)
      stats[:processed] += 1

      if result[:success]
        result[:company] ? stats[:matched] += 1 : stats[:unmatched] += 1
      else
        stats[:errors] += 1
      end
    end

    stats
  end

  # Finds all senders for a specific domain
  #
  # @param domain [String] The email domain
  # @return [Array<EmailSender>]
  def senders_for_domain(domain)
    EmailSender.by_domain(domain).order(:email)
  end

  # Assigns a company to all senders from a domain
  #
  # @param domain [String] The email domain
  # @param company [Company] The company to assign
  # @param verify [Boolean] Whether to mark as verified
  # @return [Integer] Number of senders updated
  def assign_domain_to_company(domain, company, verify: true)
    EmailSender.by_domain(domain).update_all(
      company_id: company.id,
      verified: verify,
      updated_at: Time.current
    )
  end

  private

  # Extracts domain from email address
  #
  # @param email [String]
  # @return [String]
  def extract_domain(email)
    email.to_s.split("@").last&.downcase&.strip || ""
  end

  # Checks if domain is a generic email provider
  #
  # @param domain [String]
  # @return [Boolean]
  def generic_domain?(domain)
    GENERIC_DOMAINS.include?(domain.downcase)
  end

  # Checks if domain is an ATS system
  #
  # @param domain [String]
  # @return [Boolean]
  def ats_domain?(domain)
    ATS_DOMAINS.any? { |ats| domain.include?(ats) }
  end

  # Finds company by existing email sender domain association
  #
  # @param domain [String]
  # @return [Company, nil]
  def find_by_domain(domain)
    # Check if we've already associated this domain with a company
    existing_sender = EmailSender.by_domain(domain)
      .where.not(company_id: nil)
      .first

    existing_sender&.company
  end

  # Finds company by website URL containing domain
  #
  # @param domain [String]
  # @return [Company, nil]
  def find_by_website(domain)
    return nil if ats_domain?(domain)

    Company.where("website ILIKE ?", "%#{domain}%").first ||
      Company.where("website ILIKE ?", "%#{domain.split('.').first}%").first
  end

  # Finds company by matching domain name to company name
  #
  # @param domain [String]
  # @return [Company, nil]
  def find_by_name_from_domain(domain)
    return nil if ats_domain?(domain)

    # Extract the main part of the domain (e.g., "google" from "google.com")
    domain_name = domain.split(".").first
    return nil if domain_name.length < 3

    # Try exact match first
    Company.where("LOWER(name) = ?", domain_name.downcase).first ||
      # Try partial match
      Company.where("LOWER(name) LIKE ?", "%#{domain_name.downcase}%")
        .where("LENGTH(name) < ?", domain_name.length + 10) # Avoid matching "Google Inc" to "goo"
        .first
  end

  # Finds company from sender's display name
  #
  # @param sender_name [String, nil]
  # @return [Company, nil]
  def find_by_sender_name(sender_name)
    return nil if sender_name.blank?

    # Extract potential company name from formats like:
    # "Jane at Company" or "Company Recruiting" or "Company HR"
    patterns = [
      /(?:at|from|with)\s+([A-Z][A-Za-z0-9\s&]+?)(?:\s|$)/i,
      /^([A-Z][A-Za-z0-9\s&]+?)\s+(?:Recruiting|HR|Talent|Team|Careers?)/i
    ]

    patterns.each do |pattern|
      match = sender_name.match(pattern)
      if match
        company_name = match[1].strip
        company = Company.where("LOWER(name) = ?", company_name.downcase).first
        return company if company
      end
    end

    nil
  end
end
