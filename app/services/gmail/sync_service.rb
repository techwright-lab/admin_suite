# frozen_string_literal: true

# Service for syncing emails from Gmail that may contain interview-related content
#
# @example
#   service = Gmail::SyncService.new(connected_account)
#   result = service.run
#
class Gmail::SyncService
  # Keywords that indicate an email might be interview-related
  INTERVIEW_KEYWORDS = [
    "interview",
    "interviewing",
    "phone screen",
    "technical interview",
    "coding challenge",
    "assessment",
    "hiring",
    "application status",
    "job application",
    "thank you for applying",
    "next steps",
    "schedule a call",
    "meet the team",
    "offer letter",
    "job offer",
    "congratulations",
    "we regret",
    "unfortunately",
    "position has been filled"
  ].freeze

  # Keywords that indicate recruiter outreach (new opportunity)
  RECRUITER_OUTREACH_KEYWORDS = [
    "opportunity",
    "exciting role",
    "perfect fit",
    "your profile",
    "your background",
    "reaching out",
    "interested in you",
    "open position",
    "hiring for",
    "would you be interested",
    "great match",
    "ideal candidate",
    "came across your"
  ].freeze

  # Common recruiting email domains
  RECRUITER_DOMAINS = [
    "greenhouse.io",
    "lever.co",
    "workday.com",
    "icims.com",
    "taleo.net",
    "jobvite.com",
    "smartrecruiters.com",
    "ashbyhq.com",
    "bamboohr.com"
  ].freeze

  # Domains that send recruiter outreach (LinkedIn, job boards)
  OUTREACH_DOMAINS = [
    "linkedin.com",
    "mail.linkedin.com",
    "hired.com",
    "angel.co",
    "wellfound.com",
    "dice.com",
    "indeed.com",
    "ziprecruiter.com"
  ].freeze

  # Patterns that indicate an email is NOT job-related (marketing, newsletters, etc.)
  IRRELEVANT_PATTERNS = [
    /unsubscribe.*preferences/i,
    /weekly\s+digest/i,
    /daily\s+digest/i,
    /newsletter/i,
    /marketing\s+email/i,
    /promotional/i,
    /you\s+might\s+like/i,
    /trending\s+(jobs?|posts?|articles?)/i,
    /people\s+you\s+may\s+know/i,
    /people\s+viewed\s+your\s+profile/i,
    /who\s+viewed\s+your\s+profile/i,
    /your\s+network\s+updates?/i,
    /connection\s+request/i,
    /wants\s+to\s+connect/i,
    /endorsed\s+you/i,
    /congratulate/i,
    /work\s+anniversary/i,
    /birthday/i,
    /new\s+job\s+alert/i,
    /jobs?\s+you\s+may\s+be\s+interested/i,
    /similar\s+jobs?/i,
    /job\s+recommendations?/i,
    /security\s+alert/i,
    /password\s+reset/i,
    /verify\s+your\s+email/i,
    /confirm\s+your\s+email/i,
    /account\s+update/i,
    /privacy\s+policy/i,
    /terms\s+of\s+service/i
  ].freeze

  # Subjects that indicate generic platform notifications (not direct recruiter contact)
  NOTIFICATION_SUBJECTS = [
    /^you\s+have\s+\d+\s+new/i,
    /^your\s+daily\s+job/i,
    /^your\s+weekly/i,
    /^new\s+jobs?\s+for\s+you/i,
    /^jobs?\s+matching\s+your/i,
    /^people\s+are\s+looking/i,
    /^who'?s\s+viewed/i,
    /^you\s+appeared\s+in/i,
    /^\d+\s+new\s+(jobs?|messages?|notifications?)/i
  ].freeze

  # @return [ConnectedAccount] The connected account
  attr_reader :connected_account

  # @return [User] The user
  attr_reader :user

  # @return [Integer] Maximum number of emails to process per sync
  attr_reader :max_results

  # Initialize the sync service
  #
  # @param connected_account [ConnectedAccount] The connected account with OAuth tokens
  # @param max_results [Integer] Maximum number of emails to fetch (default: 100)
  def initialize(connected_account, max_results: 100)
    @connected_account = connected_account
    @user = connected_account.user
    @max_results = max_results
    @synced_emails = []
  end

  # Runs the sync process
  #
  # @return [Hash] Results of the sync
  def run
    return { success: false, error: "Account not connected" } unless connected_account&.google?
    return { success: false, error: "Sync disabled" } unless connected_account.sync_enabled?

    begin
      emails = fetch_interview_emails
      parsed_emails = parse_emails(emails)

      # Store and process emails
      sync_results = store_and_process_emails(parsed_emails)

      connected_account.mark_synced!

      {
        success: true,
        emails_found: emails.size,
        emails_parsed: parsed_emails.size,
        emails_new: sync_results[:new_count],
        emails_processed: sync_results[:processed_count],
        emails_matched: sync_results[:matched_count],
        opportunities_created: sync_results[:opportunities_count],
        synced_at: Time.current
      }
    rescue Gmail::Errors::TokenExpiredError => e
      { success: false, error: e.message, needs_reauth: true }
    rescue Google::Apis::Error => e
      Rails.logger.error "Gmail API error: #{e.message}"
      ExceptionNotifier.notify(e, {
        context: "gmail_sync",
        severity: "error",
        operation: "gmail_api",
        connected_account_id: connected_account.id,
        user: { id: user&.id, email: user&.email_address }
      })
      { success: false, error: "Gmail API error: #{e.message}" }
    rescue StandardError => e
      Rails.logger.error "Gmail sync error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      ExceptionNotifier.notify(e, {
        context: "gmail_sync",
        severity: "error",
        operation: "sync_run",
        connected_account_id: connected_account.id,
        user: { id: user&.id, email: user&.email_address }
      })
      { success: false, error: "Sync failed: #{e.message}" }
    end
  end

  # Returns counts of synced emails by status
  #
  # @return [Hash]
  def sync_stats
    {
      total: user.synced_emails.from_account(connected_account).count,
      pending: user.synced_emails.from_account(connected_account).pending.count,
      processed: user.synced_emails.from_account(connected_account).processed.count,
      matched: user.synced_emails.from_account(connected_account).matched.count,
      opportunities: user.opportunities.actionable.count
    }
  end

  private

  # Returns the Gmail client
  #
  # @return [Gmail::ClientService]
  def client_service
    @client_service ||= Gmail::ClientService.new(connected_account)
  end

  # Returns the Gmail API client
  #
  # @return [Google::Apis::GmailV1::GmailService]
  def gmail
    client_service.client
  end

  # Fetches emails that may be interview-related
  #
  # @return [Array<Google::Apis::GmailV1::Message>]
  def fetch_interview_emails
    # Build a search query for interview-related emails
    query = build_search_query

    # Get messages matching the query
    response = gmail.list_user_messages(
      client_service.user_id,
      q: query,
      max_results: max_results
    )

    return [] unless response.messages

    # Fetch full message details for each message
    response.messages.map do |message_ref|
      gmail.get_user_message(client_service.user_id, message_ref.id)
    end
  end

  # Builds the Gmail search query
  # Refined to reduce irrelevant emails while still catching relevant ones
  #
  # @return [String]
  def build_search_query
    # Search for emails from the last 30 days
    after_date = 30.days.ago.strftime("%Y/%m/%d")

    # Build keyword query for interview-related emails (high signal)
    interview_keyword_query = INTERVIEW_KEYWORDS.map { |kw| "\"#{kw}\"" }.join(" OR ")

    # Build keyword query for recruiter outreach
    outreach_keyword_query = RECRUITER_OUTREACH_KEYWORDS.map { |kw| "\"#{kw}\"" }.join(" OR ")

    # Build domain query for ATS systems (these are always relevant)
    ats_domain_query = RECRUITER_DOMAINS.map { |d| "from:#{d}" }.join(" OR ")

    # Exclusions to filter out noise
    exclusions = [
      "-subject:\"unsubscribe\"",
      "-subject:\"newsletter\"",
      "-subject:\"digest\"",
      "-subject:\"weekly jobs\"",
      "-subject:\"daily jobs\"",
      "-subject:\"job alert\"",
      "-subject:\"jobs for you\"",
      "-subject:\"people you may know\"",
      "-subject:\"who viewed your profile\"",
      "-subject:\"connection request\"",
      "-from:noreply",
      "-from:no-reply",
      "-from:notifications@",
      "-from:marketing@"
    ].join(" ")

    # Combine all queries - look for keyword matches OR from ATS systems
    # Note: We removed OUTREACH_DOMAINS (LinkedIn, Indeed, etc.) from the OR clause
    # because they generate too much noise. Instead, we rely on keywords to catch
    # relevant recruiter outreach from those platforms.
    all_keywords = "(#{interview_keyword_query} OR #{outreach_keyword_query})"
    ats_only = "(#{ats_domain_query})"

    # Also fetch emails from companies user has applied to or is targeting
    # These are always relevant regardless of keywords
    user_domains = user_company_email_domains
    user_company_query = user_domains.any? ? " OR (#{user_domains.map { |d| "from:#{d}" }.join(' OR ')})" : ""

    "after:#{after_date} in:inbox -in:spam -in:trash #{exclusions} (#{all_keywords} OR #{ats_only}#{user_company_query})"
  end

  # Returns email domains for companies the user has applied to or is targeting
  # These companies are always relevant for email sync
  #
  # @return [Array<String>] List of email domains
  def user_company_email_domains
    @user_company_email_domains ||= begin
      # Get companies from applications and targets
      applied_companies = user.interview_applications
        .includes(:company)
        .where(status: :active)
        .map(&:company)
        .compact

      target_companies = user.target_companies.to_a

      # Combine and dedupe
      all_companies = (applied_companies + target_companies).uniq

      # Extract domains from company websites
      all_companies.filter_map do |company|
        extract_domain_from_company(company)
      end.uniq
    end
  end

  # Extracts email domain from a company's website
  #
  # @param company [Company] The company
  # @return [String, nil] The domain (e.g., "google.com")
  def extract_domain_from_company(company)
    return nil unless company.website.present?

    # Parse website URL to get domain
    url = company.website.strip
    url = "https://#{url}" unless url.start_with?("http")

    uri = URI.parse(url)
    domain = uri.host&.gsub(/^www\./, "")

    # Skip generic domains
    return nil if domain.blank? || generic_email_domain?(domain)

    domain
  rescue URI::InvalidURIError
    nil
  end

  # Checks if a domain is a generic email provider (not company-specific)
  #
  # @param domain [String] The domain to check
  # @return [Boolean]
  def generic_email_domain?(domain)
    generic = %w[
      gmail.com yahoo.com hotmail.com outlook.com
      icloud.com aol.com mail.com protonmail.com
      live.com msn.com ymail.com
    ]
    generic.include?(domain.downcase)
  end

  # Parses email messages into structured data
  #
  # @param messages [Array<Google::Apis::GmailV1::Message>]
  # @return [Array<Hash>]
  def parse_emails(messages)
    messages.filter_map { |message| parse_email(message) }
  end

  # Parses a single email message
  #
  # @param message [Google::Apis::GmailV1::Message]
  # @return [Hash, nil]
  def parse_email(message)
    headers = extract_headers(message)
    body_content = extract_body_content(message)

    {
      id: message.id,
      thread_id: message.thread_id,
      subject: headers["Subject"],
      from: headers["From"],
      to: headers["To"],
      date: parse_date(headers["Date"]),
      snippet: message.snippet,
      labels: message.label_ids,
      body_preview: body_content[:plain],
      body_html: body_content[:html]
    }
  rescue StandardError => e
    Rails.logger.error "Failed to parse email #{message.id}: #{e.class} - #{e.message}"
    ExceptionNotifier.notify(e, {
      context: "gmail_sync",
      severity: "warning",
      gmail_message_id: message.id,
      user: { id: user&.id, email: user&.email_address }
    })
    nil
  end

  # Extracts headers from a message
  #
  # @param message [Google::Apis::GmailV1::Message]
  # @return [Hash]
  def extract_headers(message)
    return {} unless message.payload&.headers

    message.payload.headers.each_with_object({}) do |header, hash|
      hash[header.name] = header.value
    end
  end

  # Parses a date string from email headers
  #
  # @param date_string [String]
  # @return [DateTime, nil]
  def parse_date(date_string)
    return nil unless date_string

    DateTime.parse(date_string)
  rescue ArgumentError
    nil
  end

  # Extracts both plain text and HTML body content from email
  #
  # @param message [Google::Apis::GmailV1::Message]
  # @return [Hash] { plain: String, html: String|nil }
  def extract_body_content(message)
    result = { plain: message.snippet.to_s, html: nil }
    return result unless message.payload

    # Extract raw HTML body (stored as-is for rendering)
    html_body = extract_body_part(message.payload, "text/html")
    if html_body.present?
      # Store HTML as-is but limit size to prevent huge emails
      result[:html] = html_body.truncate(100_000, omission: "")  # 100KB limit for HTML
    end

    # Extract plain text for preview and search
    plain_body = extract_body_part(message.payload, "text/plain")

    if plain_body.present?
      result[:plain] = clean_plain_text(plain_body)
    elsif html_body.present?
      # Convert HTML to plain text if no plain text version exists
      result[:plain] = clean_plain_text(ActionController::Base.helpers.strip_tags(html_body))
    end

    result
  end

  # Cleans up plain text content for storage
  #
  # @param text [String] Raw plain text
  # @return [String] Cleaned text
  def clean_plain_text(text)
    return "" if text.blank?

    text.gsub(/\r\n?/, "\n")           # Normalize line endings
        .gsub(/\n{3,}/, "\n\n")        # Max 2 consecutive newlines
        .gsub(/[ \t]+/, " ")           # Collapse horizontal whitespace
        .strip
        .truncate(10_000)              # Store up to 10KB of plain text
  end

  # Recursively extracts body part by MIME type
  #
  # The Google APIs gem may return body.data in two formats:
  # 1. Already decoded plain text (most common with format='full')
  # 2. Base64 encoded (URL-safe variant) which needs decoding
  #
  # @param part [Google::Apis::GmailV1::MessagePart]
  # @param mime_type [String]
  # @return [String, nil]
  def extract_body_part(part, mime_type)
    if part.mime_type == mime_type && part.body&.data.present?
      return decode_body_data(part.body.data)
    end

    return nil unless part.parts

    part.parts.each do |sub_part|
      result = extract_body_part(sub_part, mime_type)
      return result if result
    end

    nil
  rescue StandardError => e
    Rails.logger.error "Failed to extract body part (#{mime_type}): #{e.class} - #{e.message}"
    ExceptionNotifier.notify(e, {
      context: "gmail_sync",
      severity: "warning",
      operation: "extract_body_part",
      mime_type: mime_type,
      user: { id: user&.id, email: user&.email_address }
    })
    nil
  end

  # Decodes body data from Gmail API
  #
  # The Gmail API gem sometimes returns already-decoded data and sometimes
  # returns Base64 encoded data. This method handles both cases.
  #
  # @param data [String] The body data (may be decoded or Base64 encoded)
  # @return [String, nil] The decoded content
  def decode_body_data(data)
    return nil if data.blank?

    # Check if data looks like Base64 (only contains valid Base64 chars)
    # Base64 URL-safe uses: A-Z, a-z, 0-9, -, _, and optional = padding
    if data.match?(/\A[A-Za-z0-9_-]+={0,2}\z/) && data.length > 50
      # Likely Base64 encoded - try to decode
      begin
        decoded = Base64.urlsafe_decode64(data)
        # Verify it produced valid UTF-8 text
        decoded.force_encoding("UTF-8")
        return decoded if decoded.valid_encoding?
      rescue ArgumentError
        # Not valid Base64, fall through to use raw data
      end
    end

    # Data is already decoded plain text or HTML
    # Force UTF-8 encoding and handle any invalid bytes
    data.dup.force_encoding("UTF-8").scrub
  end

  # Stores parsed emails and processes them
  #
  # @param parsed_emails [Array<Hash>] Parsed email data
  # @return [Hash] Processing statistics
  def store_and_process_emails(parsed_emails)
    stats = { new_count: 0, processed_count: 0, matched_count: 0, opportunities_count: 0, auto_ignored_count: 0 }

    parsed_emails.each do |email_data|
      # Create or find existing synced email
      synced_email = SyncedEmail.create_from_gmail_message(user, connected_account, email_data)
      next unless synced_email

      # Track if this is a new email
      is_new_email = synced_email.created_at >= 1.minute.ago
      stats[:new_count] += 1 if is_new_email

      # Auto-ignore clearly irrelevant emails (marketing, notifications, etc.)
      if is_new_email && synced_email.pending? && clearly_irrelevant?(synced_email)
        synced_email.update!(status: :auto_ignored)
        stats[:auto_ignored_count] += 1
        next
      end

      # Process the email if it's pending
      if synced_email.pending?
        result = Gmail::EmailProcessorService.new(synced_email).run
        stats[:processed_count] += 1 if result[:success]

        # Auto-ignore emails classified as "other" (not job-related)
        if result[:email_type] == "other" && !synced_email.matched?
          synced_email.update!(status: :auto_ignored)
          stats[:auto_ignored_count] += 1
          next
        end

        # Check for recruiter outreach and create opportunity
        if is_new_email && result[:email_type] == "recruiter_outreach"
          opportunity = create_opportunity_from_email(synced_email)
          stats[:opportunities_count] += 1 if opportunity
        elsif synced_email.reload.matched?
          stats[:matched_count] += 1
        end

        # Queue signal extraction for relevant emails
        queue_signal_extraction(synced_email) if is_new_email
      elsif synced_email.matched?
        stats[:matched_count] += 1
      end
    end

    stats
  end

  # Checks if an email is clearly irrelevant (marketing, notifications, etc.)
  # These are platform emails that slipped through the Gmail query but aren't direct recruiter contact
  #
  # @param synced_email [SyncedEmail] The email to check
  # @return [Boolean] True if the email should be auto-ignored
  def clearly_irrelevant?(synced_email)
    # NEVER auto-ignore emails from companies user has applied to or is targeting
    # These are always relevant regardless of content patterns
    return false if from_user_company?(synced_email)

    content = [
      synced_email.subject,
      synced_email.snippet,
      synced_email.body_preview
    ].compact.join(" ")

    # Check against irrelevant patterns (newsletters, notifications, etc.)
    return true if IRRELEVANT_PATTERNS.any? { |pattern| content.match?(pattern) }

    # Check if subject matches notification-style subjects
    return true if NOTIFICATION_SUBJECTS.any? { |pattern| synced_email.subject&.match?(pattern) }

    # LinkedIn-specific: ignore if from LinkedIn but not a direct recruiter message
    if synced_email.from_email.include?("linkedin.com")
      # These are typically automated notifications, not direct recruiter outreach
      linkedin_notification_patterns = [
        /jobs-noreply/i,
        /messages-noreply/i,
        /notifications-noreply/i,
        /invitations/i,
        /member@linkedin/i
      ]
      return true if linkedin_notification_patterns.any? { |p| synced_email.from_email.match?(p) }
    end

    # Indeed/ZipRecruiter job alerts (not direct applications)
    if synced_email.from_email.match?(/indeed|ziprecruiter/i)
      return true if synced_email.subject&.match?(/jobs?\s+(for\s+you|matching|alert|digest)/i)
    end

    false
  end

  # Checks if an email is from a company the user has applied to or is targeting
  #
  # @param synced_email [SyncedEmail] The email to check
  # @return [Boolean] True if from a user's company
  def from_user_company?(synced_email)
    return false if synced_email.from_email.blank?

    sender_domain = synced_email.from_email.split("@").last&.downcase
    return false if sender_domain.blank?

    # Check if sender domain matches any user company domain
    user_company_email_domains.any? do |company_domain|
      # Match if domains are equal or one contains the other
      # (handles cases like "mail.google.com" vs "google.com")
      sender_domain == company_domain ||
        sender_domain.end_with?(".#{company_domain}") ||
        company_domain.end_with?(".#{sender_domain}")
    end
  end

  # Queues signal extraction for a synced email
  # Extracts company info, recruiter details, job information, and suggested actions
  #
  # @param synced_email [SyncedEmail] The synced email
  # @return [void]
  def queue_signal_extraction(synced_email)
    # Only queue if email is suitable for extraction
    return if synced_email.auto_ignored? || synced_email.ignored?
    return if synced_email.email_type == "other" && !synced_email.matched?
    return if synced_email.extraction_status != "pending"

    ProcessSignalExtractionJob.perform_later(synced_email.id)
  end

  # Creates an opportunity from a recruiter outreach email
  #
  # @param synced_email [SyncedEmail] The synced email
  # @return [Opportunity, nil] Created opportunity or nil
  def create_opportunity_from_email(synced_email)
    return nil if synced_email.opportunity.present?

    detector = Gmail::OpportunityDetectorService.new(synced_email)
    return nil unless detector.recruiter_outreach?

    opportunity = detector.create_opportunity!

    # Queue background job for AI extraction
    ProcessOpportunityEmailJob.perform_later(opportunity.id)

    opportunity
  rescue StandardError => e
    Rails.logger.error "Failed to create opportunity from email #{synced_email.id}: #{e.class} - #{e.message}"
    ExceptionNotifier.notify(e, {
      context: "gmail_sync",
      severity: "error",
      operation: "create_opportunity",
      synced_email_id: synced_email.id,
      user: { id: user&.id, email: user&.email_address }
    })
    nil
  end
end
