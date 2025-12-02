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
        synced_at: Time.current
      }
    rescue Gmail::TokenExpiredError => e
      { success: false, error: e.message, needs_reauth: true }
    rescue Google::Apis::Error => e
      Rails.logger.error "Gmail API error: #{e.message}"
      { success: false, error: "Gmail API error: #{e.message}" }
    rescue StandardError => e
      Rails.logger.error "Gmail sync error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
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
      matched: user.synced_emails.from_account(connected_account).matched.count
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
  #
  # @return [String]
  def build_search_query
    # Search for emails from the last 30 days
    after_date = 30.days.ago.strftime("%Y/%m/%d")

    # Build keyword query
    keyword_query = INTERVIEW_KEYWORDS.map { |kw| "\"#{kw}\"" }.join(" OR ")

    # Build domain query for ATS systems
    domain_query = RECRUITER_DOMAINS.map { |d| "from:#{d}" }.join(" OR ")

    # Combine queries - look for keyword matches OR from known recruiting systems
    # Only in inbox and important/starred, exclude spam and trash
    "after:#{after_date} in:inbox -in:spam -in:trash (#{keyword_query} OR #{domain_query})"
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

    {
      id: message.id,
      thread_id: message.thread_id,
      subject: headers["Subject"],
      from: headers["From"],
      to: headers["To"],
      date: parse_date(headers["Date"]),
      snippet: message.snippet,
      labels: message.label_ids,
      body_preview: extract_body_preview(message)
    }
  rescue StandardError => e
    Rails.logger.warn "Failed to parse email #{message.id}: #{e.message}"
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

  # Extracts a preview of the email body
  #
  # @param message [Google::Apis::GmailV1::Message]
  # @return [String]
  def extract_body_preview(message)
    # Start with the snippet
    return message.snippet.to_s.truncate(500) unless message.payload

    # Try to get plain text body
    body = extract_body_part(message.payload, "text/plain")
    body ||= extract_body_part(message.payload, "text/html")

    if body
      # Clean up HTML if present
      body = ActionController::Base.helpers.strip_tags(body) if body.include?("<")
      body.squish.truncate(500)
    else
      message.snippet.to_s.truncate(500)
    end
  end

  # Recursively extracts body part by MIME type
  #
  # @param part [Google::Apis::GmailV1::MessagePart]
  # @param mime_type [String]
  # @return [String, nil]
  def extract_body_part(part, mime_type)
    if part.mime_type == mime_type && part.body&.data
      return Base64.urlsafe_decode64(part.body.data)
    end

    return nil unless part.parts

    part.parts.each do |sub_part|
      result = extract_body_part(sub_part, mime_type)
      return result if result
    end

    nil
  rescue ArgumentError
    # Base64 decode failed
    nil
  end

  # Stores parsed emails and processes them
  #
  # @param parsed_emails [Array<Hash>] Parsed email data
  # @return [Hash] Processing statistics
  def store_and_process_emails(parsed_emails)
    stats = { new_count: 0, processed_count: 0, matched_count: 0 }

    parsed_emails.each do |email_data|
      # Create or find existing synced email
      synced_email = SyncedEmail.create_from_gmail_message(user, connected_account, email_data)
      next unless synced_email

      # Track if this is a new email
      stats[:new_count] += 1 if synced_email.created_at >= 1.minute.ago

      # Process the email if it's pending
      if synced_email.pending?
        result = Gmail::EmailProcessorService.new(synced_email).run
        stats[:processed_count] += 1 if result[:success]
        stats[:matched_count] += 1 if synced_email.reload.matched?
      elsif synced_email.matched?
        stats[:matched_count] += 1
      end
    end

    stats
  end
end

