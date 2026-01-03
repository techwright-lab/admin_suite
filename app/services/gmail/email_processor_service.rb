# frozen_string_literal: true

# Service for processing synced emails to classify type and match to applications
#
# @example
#   processor = Gmail::EmailProcessorService.new(synced_email)
#   result = processor.run
#
class Gmail::EmailProcessorService
  # Keywords for detecting email types
  EMAIL_TYPE_PATTERNS = {
    interview_invite: [
      /interview\s+(invitation|invite|scheduled|confirmed)/i,
      /schedule\s+(a|an|your)\s+interview/i,
      /invit(e|ing)\s+you\s+(to|for)\s+(an?\s+)?interview/i,
      /would\s+like\s+to\s+interview/i,
      /meet\s+with\s+(our|the)\s+team/i,
      /phone\s+screen/i,
      /technical\s+interview/i,
      /on-?site\s+interview/i,
      /video\s+interview/i,
      /zoom\s+interview/i
    ],
    scheduling: [
      /schedule\s+(a\s+)?(call|meeting|time)/i,
      /book\s+(a\s+)?time/i,
      /calendly/i,
      /pick\s+a\s+time/i,
      /available\s+times?/i,
      /when\s+are\s+you\s+available/i
    ],
    application_confirmation: [
      /thank\s+you\s+for\s+(applying|your\s+application)/i,
      /application\s+(received|submitted|confirmed)/i,
      /we\s+(have\s+)?received\s+your\s+application/i,
      /successfully\s+applied/i,
      /application\s+for\s+.+\s+position/i
    ],
    rejection: [
      /we\s+(regret|unfortunately|are\s+sorry)/i,
      /not\s+(be\s+)?moving\s+forward/i,
      /decided\s+(not\s+)?to\s+proceed/i,
      /position\s+has\s+been\s+filled/i,
      /other\s+candidates/i,
      /not\s+a\s+(good\s+)?fit/i,
      /won'?t\s+be\s+(moving|proceeding)/i,
      /pursuing\s+other\s+candidates/i
    ],
    offer: [
      /offer\s+(letter|of\s+employment)/i,
      /pleased\s+to\s+offer/i,
      /extend(ing)?\s+(an?\s+)?offer/i,
      /job\s+offer/i,
      /congratulations/i,
      /welcome\s+to\s+the\s+team/i,
      /excited\s+to\s+have\s+you\s+join/i
    ],
    assessment: [
      /coding\s+(challenge|test|assessment)/i,
      /take-?home\s+(assignment|test|project)/i,
      /technical\s+assessment/i,
      /skills?\s+assessment/i,
      /hackerrank/i,
      /codility/i,
      /leetcode/i,
      /complete\s+the\s+(following\s+)?assessment/i
    ],
    follow_up: [
      /following\s+up/i,
      /checking\s+in/i,
      /wanted\s+to\s+follow\s+up/i,
      /any\s+updates?/i,
      /status\s+of\s+(my|your)\s+application/i
    ],
    thank_you: [
      /thank\s+you\s+for\s+(your\s+time|meeting|interviewing)/i,
      /great\s+meeting\s+you/i,
      /enjoyed\s+(speaking|talking|meeting)/i
    ],
    recruiter_outreach: [
      /exciting\s+(opportunity|role|position)/i,
      /perfect\s+fit/i,
      /great\s+fit/i,
      /your\s+(profile|background|experience)/i,
      /reaching\s+out/i,
      /interested\s+in\s+you/i,
      /open\s+position/i,
      /hiring\s+for/i,
      /would\s+you\s+be\s+interested/i,
      /great\s+match/i,
      /ideal\s+candidate/i,
      /thought\s+of\s+you/i,
      /came\s+across\s+your/i,
      /found\s+your\s+profile/i,
      /saw\s+your\s+resume/i,
      /impressive\s+background/i,
      /looking\s+for\s+someone/i,
      /we\s+have\s+an\s+opening/i,
      /new\s+opportunity/i,
      /career\s+opportunity/i
    ]
  }.freeze

  # @return [SyncedEmail] The email to process
  attr_reader :synced_email

  # Initialize the processor
  #
  # @param synced_email [SyncedEmail] The email to process
  def initialize(synced_email)
    @synced_email = synced_email
  end

  # Runs the processing pipeline
  #
  # @return [Hash] Processing result
  def run
    return already_processed_result if synced_email.processed? || synced_email.ignored?

    ActiveRecord::Base.transaction do
      classify_email_type
      detect_company
      match_to_application
      synced_email.save!
    end

    {
      success: true,
      email_type: synced_email.email_type,
      matched_application: synced_email.interview_application_id,
      detected_company: synced_email.detected_company
    }
  rescue StandardError => e
    Rails.logger.error "Email processing failed for #{synced_email.id}: #{e.message}"
    synced_email.mark_failed!(e.message)
    { success: false, error: e.message }
  end

  private

  # Returns result for already processed emails
  #
  # @return [Hash]
  def already_processed_result
    {
      success: true,
      email_type: synced_email.email_type,
      matched_application: synced_email.interview_application_id,
      already_processed: true
    }
  end

  # Classifies the email type based on content patterns
  # Emails from target companies get boosted relevance
  #
  # @return [void]
  def classify_email_type
    content = [
      synced_email.subject,
      synced_email.snippet,
      synced_email.body_preview
    ].compact.join(" ")

    EMAIL_TYPE_PATTERNS.each do |type, patterns|
      if patterns.any? { |pattern| content.match?(pattern) }
        synced_email.email_type = type.to_s
        return
      end
    end

    # Boost relevance: If from a target company but no pattern matched,
    # classify as recruiter_outreach since it's likely relevant
    if from_target_company?
      synced_email.email_type = "recruiter_outreach"
      return
    end

    # Default to "other" if no pattern matched and not from target company
    synced_email.email_type = "other"
  end

  # Checks if the email is from a company the user is targeting
  #
  # @return [Boolean]
  def from_target_company?
    return false if synced_email.from_email.blank?

    sender_domain = synced_email.from_email.split("@").last&.downcase
    return false if sender_domain.blank? || generic_domain?(sender_domain)

    target_domains = user_target_company_domains
    target_domains.any? do |company_domain|
      sender_domain == company_domain ||
        sender_domain.end_with?(".#{company_domain}") ||
        company_domain.end_with?(".#{sender_domain}")
    end
  end

  # Returns email domains for the user's target companies
  #
  # @return [Array<String>]
  def user_target_company_domains
    @user_target_company_domains ||= synced_email.user.target_companies.filter_map do |company|
      next unless company.website.present?

      url = company.website.strip
      url = "https://#{url}" unless url.start_with?("http")

      uri = URI.parse(url)
      uri.host&.gsub(/^www\./, "")&.downcase
    rescue URI::InvalidURIError
      nil
    end.uniq
  end

  # Detects company name from email content
  #
  # @return [void]
  def detect_company
    # Try sender's company first
    if synced_email.email_sender&.effective_company
      synced_email.detected_company = synced_email.email_sender.effective_company.name
      return
    end

    # Try to extract from email domain
    domain = synced_email.from_email.split("@").last
    company = find_company_by_domain(domain)

    if company
      synced_email.detected_company = company.name
      # Also update the sender's auto-detected company
      synced_email.email_sender&.update(auto_detected_company: company)
      return
    end

    # Try to extract company name from subject or content
    extracted_name = extract_company_from_content
    synced_email.detected_company = extracted_name if extracted_name
  end

  # Finds a company by email domain
  #
  # @param domain [String] The email domain
  # @return [Company, nil]
  def find_company_by_domain(domain)
    return nil if domain.blank? || generic_domain?(domain)

    # Try exact website match
    Company.where("website ILIKE ?", "%#{domain}%").first ||
      # Try company name match
      Company.where("LOWER(name) = ?", extract_company_from_domain(domain).downcase).first
  end

  # Checks if domain is a generic email provider
  #
  # @param domain [String]
  # @return [Boolean]
  def generic_domain?(domain)
    generic_domains = %w[
      gmail.com yahoo.com hotmail.com outlook.com
      icloud.com aol.com mail.com protonmail.com
    ]
    generic_domains.include?(domain.downcase)
  end

  # Extracts company name from domain
  #
  # @param domain [String]
  # @return [String]
  def extract_company_from_domain(domain)
    # Remove common TLDs and get the main part
    domain.split(".").first.titleize
  end

  # Extracts company name from email content
  #
  # @return [String, nil]
  def extract_company_from_content
    content = "#{synced_email.subject} #{synced_email.snippet}"

    # Pattern: "at [Company]" or "from [Company]" or "[Company] Team"
    patterns = [
      /(?:at|from|with)\s+([A-Z][A-Za-z0-9\s&]+?)(?:\s+team|\s+inc|\s+llc|\s+corp|,|\.|!|\?|$)/i,
      /([A-Z][A-Za-z0-9\s&]+?)\s+(?:team|recruiting|talent|hr)\s+/i,
      /application\s+(?:for|to|at)\s+([A-Z][A-Za-z0-9\s&]+)/i
    ]

    patterns.each do |pattern|
      match = content.match(pattern)
      return match[1].strip if match && match[1].length > 2 && match[1].length < 50
    end

    nil
  end

  # Matches the email to an existing application
  #
  # @return [void]
  def match_to_application
    return if synced_email.interview_application_id.present?

    application = find_matching_application
    if application
      synced_email.interview_application = application
      synced_email.status = :processed
    else
      # Leave as pending for manual review
      synced_email.status = :pending
    end
  end

  # Finds an application that matches this email
  #
  # @return [InterviewApplication, nil]
  def find_matching_application
    user = synced_email.user

    # Strategy 1: Match by company name
    if synced_email.detected_company.present?
      company = Company.where("LOWER(name) = ?", synced_email.detected_company.downcase).first
      if company
        app = user.interview_applications
          .where(company: company)
          .where(status: :active)
          .order(created_at: :desc)
          .first
        return app if app
      end
    end

    # Strategy 2: Match by sender's company
    if synced_email.email_sender&.effective_company
      app = user.interview_applications
        .where(company: synced_email.email_sender.effective_company)
        .where(status: :active)
        .order(created_at: :desc)
        .first
      return app if app
    end

    # Strategy 3: Match by sender domain to application companies
    app = match_by_sender_domain(user)
    return app if app

    # Strategy 4: Match by email thread (same thread = same application)
    if synced_email.thread_id.present?
      existing = SyncedEmail.where(user: user, thread_id: synced_email.thread_id)
        .where.not(interview_application_id: nil)
        .first
      return existing.interview_application if existing
    end

    nil
  end

  # Matches email to application by comparing sender domain to company websites
  #
  # @param user [User] The user
  # @return [InterviewApplication, nil]
  def match_by_sender_domain(user)
    sender_domain = synced_email.from_email.split("@").last&.downcase
    return nil if sender_domain.blank? || generic_domain?(sender_domain)

    # Find applications where the company website matches the sender domain
    user.interview_applications
      .includes(:company)
      .where(status: :active)
      .find do |app|
        company = app.company
        next unless company&.website.present?

        company_domain = extract_domain_from_website(company.website)
        next unless company_domain

        # Check if domains match
        sender_domain == company_domain ||
          sender_domain.end_with?(".#{company_domain}") ||
          company_domain.end_with?(".#{sender_domain}")
      end
  end

  # Extracts domain from a website URL
  #
  # @param website [String] The website URL
  # @return [String, nil]
  def extract_domain_from_website(website)
    url = website.strip
    url = "https://#{url}" unless url.start_with?("http")

    uri = URI.parse(url)
    uri.host&.gsub(/^www\./, "")&.downcase
  rescue URI::InvalidURIError
    nil
  end
end
