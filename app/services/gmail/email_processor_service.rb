# frozen_string_literal: true

# Service for processing synced emails to classify type and match to applications
#
# @example
#   processor = Gmail::EmailProcessorService.new(synced_email)
#   result = processor.run
#
class Gmail::EmailProcessorService
  PROXY_SENDER_DOMAINS = %w[
    linkedin.com
    mail.linkedin.com
  ].freeze

  PROXY_SENDER_EMAILS = %w[
    inmail-hit-reply@linkedin.com
  ].freeze

  # Keywords for detecting email types
  EMAIL_TYPE_PATTERNS = {
    interview_invite: [
      /interview\s+(invitation|invite|scheduled|confirmed)/i,
      /schedule\s+(a|an|your|the)\s+interview/i,
      /invit(e|ing)\s+you\s+(to|for)\s+(an?\s+)?interview/i,
      /would\s+like\s+to\s+interview/i,
      /meet\s+with\s+(our|the)\s+team/i,
      /phone\s+screen/i,
      /technical\s+interview/i,
      /on-?site\s+interview/i,
      /video\s+interview/i,
      /zoom\s+(interview|call|meeting)/i,
      # Subject line patterns (high signal)
      /\b(first|initial|final|next|second|third)\s+interview\b/i,
      /interview\s+(with|at)\s+\w+/i,
      # Recruiter scheduling interview
      /I\s+recruit/i,
      /recruiter\s+(at|for|from)/i,
      /set\s+up\s+(a\s+)?time\s+(for\s+us\s+)?to\s+(chat|talk|meet|speak)/i,
      /excited\s+to\s+(get\s+to\s+)?know\s+you/i
    ],
    scheduling: [
      /schedule\s+(a\s+|the\s+)?(call|meeting|time)/i,
      /book\s+(a\s+)?time/i,
      /calendly/i,
      /goodtime\.io/i,
      /pick\s+a\s+time/i,
      /available\s+times?/i,
      /when\s+are\s+you\s+available/i,
      /set\s+up\s+(a\s+)?time/i,
      /visit\s+this\s+link/i
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
    ],
    round_feedback: [
      # Pass/move forward patterns
      /you('ve| have)?\s+(passed|cleared|moved forward)/i,
      /pleased\s+to\s+inform\s+you/i,
      /congratulations.*next\s+(round|stage)/i,
      /moving\s+(you\s+)?(forward|ahead)/i,
      /advancing\s+to\s+(the\s+)?next/i,
      /proceed(ing)?\s+to\s+(the\s+)?(next|final)/i,
      /happy\s+to\s+share.*(passed|moved)/i,
      /great\s+news.*(passed|next\s+round)/i,
      # Rejection patterns (for single round, not full rejection)
      /unfortunately.*not\s+(moving|proceeding)/i,
      /decided\s+not\s+to\s+move\s+forward/i,
      # Feedback patterns
      /feedback\s+(from|on)\s+your\s+(interview|round)/i,
      /interview\s+feedback/i,
      /results?\s+(of|from)\s+(your\s+)?interview/i,
      /outcome\s+(of|from)\s+(your\s+)?interview/i,
      /update\s+on\s+your\s+(interview|round)/i,
      # Waitlist patterns
      /waitlist(ed)?/i,
      /hold\s+for\s+now/i,
      /keep\s+you\s+in\s+mind/i
    ]
  }.freeze

  # Priority order when multiple email types match
  EMAIL_TYPE_PRIORITY = %w[
    rejection
    round_feedback
    offer
    assessment
    scheduling
    interview_invite
    application_confirmation
    follow_up
    thank_you
    recruiter_outreach
  ].freeze

  SELF_SENT_TYPE_BLACKLIST = %w[
    rejection
    round_feedback
    offer
  ].freeze

  # @return [SyncedEmail] The email to process
  attr_reader :synced_email

  # Initialize the processor
  #
  # @param synced_email [SyncedEmail] The email to process
  # @param pipeline_run [Signals::EmailPipelineRun, nil] Optional pipeline run for observability
  def initialize(synced_email, pipeline_run: nil)
    @synced_email = synced_email
    @pipeline_recorder = Signals::Observability::EmailPipelineRecorder.for_run(pipeline_run)
  end

  # Runs the processing pipeline
  #
  # @return [Hash] Processing result
  def run
    return already_processed_result if synced_email.processed? || synced_email.ignored?

    ActiveRecord::Base.transaction do
      if pipeline_recorder
        pipeline_recorder.measure(:email_classification) do
          classify_email_type
          { "email_type" => synced_email.email_type }
        end

        pipeline_recorder.measure(:company_detection) do
          detect_company
          { "detected_company" => synced_email.detected_company }
        end

        pipeline_recorder.measure(:application_match) do
          match_to_application
          { "interview_application_id" => synced_email.interview_application_id }
        end
      else
        classify_email_type
        detect_company
        match_to_application
      end
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

  def pipeline_recorder
    @pipeline_recorder
  end

  # Classifies the email type based on content patterns
  # Emails from target companies get boosted relevance
  #
  # @return [void]
  def classify_email_type
    # LinkedIn and similar proxy senders can include misleading keywords (e.g. "JOB OFFER")
    # in the subject even when the content is just recruiter outreach.
    if proxy_sender?
      detector = Gmail::OpportunityDetectorService.new(synced_email)
      if detector.recruiter_outreach?
        synced_email.email_type = "recruiter_outreach"
        return
      end
    end

    content = classification_content
    matched_types = EMAIL_TYPE_PATTERNS.filter_map do |type, patterns|
      type.to_s if patterns.any? { |pattern| content.match?(pattern) }
    end

    if self_sent_email?
      matched_types -= SELF_SENT_TYPE_BLACKLIST
    end

    # "job offer" alone is not strong enough signal for proxy senders (LinkedIn InMail, etc.)
    if proxy_sender? && matched_types.include?("offer") && !strong_offer_signal?(content)
      matched_types -= [ "offer" ]
    end

    if matched_types.any?
      synced_email.email_type = choose_email_type(matched_types)
      return
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

  # Chooses the email type based on priority order
  #
  # @param matched_types [Array<String>]
  # @return [String]
  def choose_email_type(matched_types)
    EMAIL_TYPE_PRIORITY.find { |type| matched_types.include?(type) } || matched_types.first
  end

  # Builds the content used for email classification
  #
  # @return [String]
  def classification_content
    subject = synced_email.subject.to_s
    body = primary_body_content
    return [ subject, body ].join(" ").strip if body.present?

    [ subject, synced_email.snippet, synced_email.body_preview ].compact.join(" ")
  end

  # Extracts the primary body content (removes quoted replies/forwards)
  #
  # @return [String]
  def primary_body_content
    body = synced_email.body_preview.presence || synced_email.snippet.to_s
    return "" if body.blank?

    lines = body.split("\n")
    cutoff = lines.index { |line| reply_separator?(line) }
    trimmed_lines = cutoff ? lines[0...cutoff] : lines
    trimmed_lines = trimmed_lines.reject { |line| line.lstrip.start_with?(">") }
    trimmed = trimmed_lines.join("\n")
    trimmed = trimmed.strip
    trimmed.presence || body
  end

  # Checks if a line indicates the start of quoted content
  #
  # @param line [String]
  # @return [Boolean]
  def reply_separator?(line)
    normalized = line.to_s.strip
    [
      /^On .+ wrote:$/i,
      /^On .+sent:$/i,
      /^On .+wrote$/i,
      /^From:\s+/i,
      /^Sent:\s+/i,
      /^To:\s+/i,
      /^Subject:\s+/i,
      /^-----Original Message-----/i,
      /^----- Forwarded message -----/i,
      /^Begin forwarded message:/i
    ].any? { |pattern| normalized.match?(pattern) }
  end

  # Checks if the email was sent by the user
  #
  # @return [Boolean]
  def self_sent_email?
    sender = synced_email.from_email.to_s.downcase
    return false if sender.blank?

    account_email = synced_email.connected_account&.email.to_s.downcase
    user_email = synced_email.user&.email_address.to_s.downcase

    sender == account_email || sender == user_email
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
  # Uses multiple strategies in order of reliability:
  # 1. Thread-based matching (same conversation = same application)
  # 2. Sender consistency (emails from same person go to same application)
  # 3. Company name matching
  # 4. Sender's assigned company
  # 5. Domain-based matching
  #
  # @return [InterviewApplication, nil]
  def find_matching_application
    user = synced_email.user

    # Proxy senders (e.g. LinkedIn InMail) can only auto-match with high confidence.
    # We treat "same thread already matched" as high-confidence, but we never use
    # sender-consistency or other heuristics for proxy senders.
    if proxy_sender?
      return match_proxy_sender_by_thread(user)
    end

    # Strategy 1: Match by email thread (same thread = same application)
    # This is highest priority to maintain conversation continuity
    if synced_email.thread_id.present?
      existing = SyncedEmail.where(user: user, thread_id: synced_email.thread_id)
        .where.not(interview_application_id: nil)
        .first
      return existing.interview_application if existing
    end

    # Strategy 2: Match by sender consistency (same sender = same application)
    # If we already have emails from this sender matched to an active application,
    # keep them together to avoid splitting conversations across applications
    if synced_email.from_email.present?
      existing = SyncedEmail.where(user: user, from_email: synced_email.from_email)
        .where.not(interview_application_id: nil)
        .joins(:interview_application)
        .where(interview_applications: { status: :active })
        .order(email_date: :desc)
        .first
      return existing.interview_application if existing
    end

    # Strategy 3: Match by company name
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

    # Strategy 4: Match by sender's company
    if synced_email.email_sender&.effective_company
      app = user.interview_applications
        .where(company: synced_email.email_sender.effective_company)
        .where(status: :active)
        .order(created_at: :desc)
        .first
      return app if app
    end

    # Strategy 5: Match by sender domain to application companies
    app = match_by_sender_domain(user)
    return app if app

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

  def proxy_sender?
    from = synced_email.from_email.to_s.downcase
    return true if PROXY_SENDER_EMAILS.include?(from)

    domain = from.split("@").last
    return false if domain.blank?

    PROXY_SENDER_DOMAINS.include?(domain)
  end

  def match_proxy_sender_by_thread(user)
    return nil if synced_email.thread_id.blank?

    app_ids =
      SyncedEmail.where(user: user, thread_id: synced_email.thread_id)
        .where.not(interview_application_id: nil)
        .distinct
        .pluck(:interview_application_id)

    return nil unless app_ids.size == 1

    user.interview_applications.find_by(id: app_ids.first, status: :active) ||
      user.interview_applications.find_by(id: app_ids.first)
  end

  def strong_offer_signal?(content)
    return false if content.blank?

    [
      /offer\s+(letter|of\s+employment)/i,
      /pleased\s+to\s+offer/i,
      /extend(ing)?\s+(an?\s+)?offer/i,
      /welcome\s+to\s+the\s+team/i,
      /excited\s+to\s+have\s+you\s+join/i
    ].any? { |pattern| content.match?(pattern) }
  end
end
