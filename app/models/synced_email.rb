# frozen_string_literal: true

# SyncedEmail model for tracking emails synced from Gmail
# Links emails to interview applications and tracks processing status
#
# Includes AI-powered signal extraction to derive actionable intelligence
# from email content (company info, recruiter details, job information).
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
    round_feedback
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
    round_feedback
    rejection
    offer
    follow_up
    scheduling
    assessment
  ].freeze

  # Types that represent potential opportunities
  OPPORTUNITY_TYPES = %w[recruiter_outreach interview_invite follow_up].freeze

  # Extraction status values
  EXTRACTION_STATUSES = %w[pending processing completed failed skipped].freeze

  # Backend actions that require user decision (not automatic)
  # Note: match_application is handled by the dropdown in the detail panel
  SUGGESTED_ACTIONS = %w[
    start_application
  ].freeze

  # Safe CSS properties that can be preserved in email HTML
  # These are visual properties that don't pose security risks
  SAFE_STYLE_PROPERTIES = %w[
    text-align text-decoration color background-color background
    font-weight font-style font-size line-height font-family
    padding padding-top padding-bottom padding-left padding-right
    margin margin-top margin-bottom margin-left margin-right
    border border-radius border-color border-width border-style
    border-top border-bottom border-left border-right
    width max-width min-width height max-height min-height
    display vertical-align white-space word-wrap overflow
    table-layout border-collapse border-spacing
    list-style list-style-type
  ].freeze

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
  validates :email_type, inclusion: { in: EMAIL_TYPES }, allow_blank: true

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

  # Store accessors for extracted signal intelligence
  # Company information
  store_accessor :extracted_data,
    :signal_company_name, :signal_company_website, :signal_company_careers_url, :signal_company_domain,
    # Recruiter information
    :signal_recruiter_name, :signal_recruiter_email, :signal_recruiter_title, :signal_recruiter_linkedin,
    # Job information
    :signal_job_title, :signal_job_department, :signal_job_location, :signal_job_url, :signal_job_salary_hint,
    # Action links (LLM-classified URLs with dynamic labels) and backend actions
    :signal_action_links, :signal_suggested_actions

  # Extraction scopes
  scope :extraction_pending, -> { where(extraction_status: "pending") }
  scope :extraction_completed, -> { where(extraction_status: "completed") }
  scope :extraction_failed, -> { where(extraction_status: "failed") }
  scope :needs_extraction, -> { where(extraction_status: [ "pending", "failed" ]) }
  scope :has_signals, -> { where.not(extracted_data: {}) }

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

  # Marks this email as processed (manual override).
  #
  # @return [Boolean]
  def mark_processed!
    update!(status: :processed)
  end

  # Marks this email as needing review (manual override).
  #
  # The "needs review" concept is derived (pending + unmatched), not a persisted status.
  # This action resets the email back to pending and clears any application match.
  #
  # @return [Boolean]
  def mark_needs_review!
    update!(status: :pending, interview_application: nil)
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

  # Signal Extraction Methods
  # -------------------------

  # Checks if signal extraction has been completed
  #
  # @return [Boolean]
  def extraction_completed?
    extraction_status == "completed"
  end

  # Checks if this email has extracted signals
  #
  # @return [Boolean]
  def has_signals?
    extracted_data.present? && extracted_data.keys.any?
  end

  # Checks if this email has company information extracted
  #
  # @return [Boolean]
  def has_company_signal?
    signal_company_name.present?
  end

  # Checks if this email has recruiter information extracted
  #
  # @return [Boolean]
  def has_recruiter_signal?
    signal_recruiter_name.present? || signal_recruiter_email.present?
  end

  # Checks if this email has job information extracted
  #
  # @return [Boolean]
  def has_job_signal?
    signal_job_title.present? || signal_job_url.present?
  end

  # Checks if this email has action links extracted
  #
  # @return [Boolean]
  def has_action_links?
    signal_action_links.present? && signal_action_links.any?
  end

  # Returns the list of backend actions for this email
  #
  # @return [Array<String>]
  def suggested_actions
    signal_suggested_actions || []
  end

  # Returns action links sorted by priority (1=highest)
  # Each link has: url, action_label, priority
  #
  # @return [Array<Hash>]
  def action_links
    links = signal_action_links || []
    links.sort_by { |link| link["priority"] || 5 }
  end

  # Returns the highest priority action link (usually scheduling or apply)
  #
  # @return [Hash, nil]
  def primary_action_link
    action_links.first
  end

  # Checks if there's a scheduling-related action link
  #
  # @return [Boolean]
  def has_scheduling_link?
    action_links.any? do |link|
      label = link["action_label"].to_s.downcase
      label.include?("schedule") || label.include?("book") || label.include?("calendar")
    end
  end

  # Returns scheduling-related action links
  #
  # @return [Array<Hash>]
  def scheduling_links
    action_links.select do |link|
      label = link["action_label"].to_s.downcase
      label.include?("schedule") || label.include?("book") || label.include?("calendar")
    end
  end

  # Marks extraction as started
  #
  # @return [Boolean]
  def mark_extraction_processing!
    update!(extraction_status: "processing")
  end

  # Updates with extraction results
  #
  # @param data [Hash] Extracted data
  # @param confidence [Float] Confidence score (0.0-1.0)
  # @return [Boolean]
  def update_extraction!(data, confidence: nil)
    update!(
      extracted_data: data,
      extraction_status: "completed",
      extraction_confidence: confidence,
      extracted_at: Time.current
    )
  end

  # Marks extraction as failed
  #
  # @param reason [String] Failure reason
  # @return [Boolean]
  def mark_extraction_failed!(reason = nil)
    update!(
      extraction_status: "failed",
      extracted_data: extracted_data.merge("extraction_error" => reason)
    )
  end

  # Marks extraction as skipped (not worth extracting)
  #
  # @return [Boolean]
  def mark_extraction_skipped!
    update!(extraction_status: "skipped")
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
  # Security measures:
  # - Allowlist of safe HTML tags only
  # - Style attributes sanitized to only allow safe CSS properties
  # - URL scheme validation for href/src (blocks javascript:, data:, etc.)
  #
  # @return [String, nil]
  def safe_html_body
    return nil unless body_html.present?

    # First pass: Remove unwanted elements and extract/sanitize styles
    # We extract styles because Rails sanitizer strips url() values
    cleaned_html, style_map = strip_unwanted_html_with_styles(body_html)

    # Second pass: Rails sanitizer with safe list of tags
    # Exclude style attribute - Rails strips url() values
    # Include data-se-style-id for style re-injection
    # width/height preserved for proper image sizing
    sanitized = ActionController::Base.helpers.sanitize(
      cleaned_html,
      tags: %w[p br div span a ul ol li strong b em i u h1 h2 h3 h4 h5 h6 blockquote pre code table tr td th thead tbody hr img],
      attributes: %w[href src alt title class target width height align valign data-se-style-id]
    )

    # Third pass: Re-inject sanitized styles that were preserved
    sanitized = reinject_styles(sanitized, style_map)

    # Fourth pass: Validate URL schemes in href and src attributes
    # Only allow http, https, and mailto schemes
    sanitize_url_schemes(sanitized)
  end

  private

  # Removes unwanted HTML elements and extracts sanitized styles
  # Returns both cleaned HTML and a map of element IDs to their safe styles
  #
  # Rails sanitizer strips url() from styles, so we extract styles first,
  # let Rails sanitize the rest, then re-inject the safe styles after.
  #
  # @param html [String] Raw HTML string
  # @return [Array<String, Hash>] [cleaned_html, style_map]
  def strip_unwanted_html_with_styles(html)
    fragment = Nokogiri::HTML::DocumentFragment.parse(html)
    style_map = {}
    style_counter = 0

    # Remove non-content elements entirely
    fragment.css("style, script, noscript, head, title, meta, link").remove

    # Remove elements hidden via inline styles, extract safe styles from others
    fragment.css("*[style]").each do |node|
      style = node["style"].to_s.downcase
      if style.include?("display:none") || style.include?("display: none") ||
         style.include?("visibility:hidden") || style.include?("visibility: hidden") ||
         style.include?("font-size:0") || style.include?("font-size: 0") ||
         style.include?("line-height:0") || style.include?("line-height: 0") ||
         style.include?("max-height:0") || style.include?("max-height: 0")
        node.remove
        next
      end

      # Sanitize style attribute to only allow safe CSS properties
      safe_style = extract_safe_styles(node["style"])
      if safe_style.present?
        # Store the safe style with a unique marker
        style_id = "se-style-#{style_counter += 1}"
        style_map[style_id] = safe_style
        # Add a data attribute that Rails won't strip
        node["data-se-style-id"] = style_id
      end
      # Remove the style attribute so Rails doesn't mangle it
      node.remove_attribute("style")
    end

    # Remove tracking pixels and tiny images (1x1, 0x0, etc.)
    fragment.css("img").each do |img|
      width = img["width"].to_s.gsub(/\D/, "").to_i
      height = img["height"].to_s.gsub(/\D/, "").to_i
      # Remove if explicitly tiny (tracking pixels)
      if (width > 0 && width <= 3) || (height > 0 && height <= 3)
        img.remove
      end
    end

    # Remove HTML comments
    fragment.traverse do |node|
      node.remove if node.comment?
    end

    # Remove empty elements that create whitespace (multiple passes)
    2.times do
      fragment.css("div, span, p, td, tr, table").each do |node|
        # Check if element has no meaningful content
        text_content = node.text.to_s.strip
        has_images = node.css("img").any?
        has_links = node.css("a").any? { |a| a.text.to_s.strip.present? }

        # Remove if empty (no text, no images, no meaningful links)
        if text_content.empty? && !has_images && !has_links
          # Keep if it has child elements with content
          has_content_children = node.children.any? do |child|
            child.element? && (child.text.to_s.strip.present? || child.css("img").any?)
          end
          node.remove unless has_content_children
        end
      end
    end

    # Remove leading br tags
    while (first = fragment.children.first) && first.name == "br"
      first.remove
    end

    # Detect and mark signature sections (images after text content ends)
    mark_signature_images(fragment)

    [fragment.to_html, style_map]
  rescue StandardError
    [html, {}]
  end

  # Marks images that appear to be in email signatures
  # Signatures typically appear after the main text content
  #
  # @param fragment [Nokogiri::HTML::DocumentFragment]
  def mark_signature_images(fragment)
    all_images = fragment.css("img").to_a
    return if all_images.empty?

    # Find signature section by looking for common patterns
    signature_indicators = [
      "Best regards", "Kind regards", "Regards", "Thanks", "Thank you",
      "Cheers", "Best,", "Sincerely", "Warmly", "Yours",
      "Get Outlook", "Sent from", "—", "--"
    ]

    # Count images and their positions
    total_text_length = fragment.text.to_s.length
    
    all_images.each_with_index do |img, idx|
      src = img["src"].to_s.downcase
      alt = img["alt"].to_s.downcase
      
      # Calculate approximate position of this image in the document
      text_before_img = ""
      img.traverse { |n| break if n == img; text_before_img += n.text.to_s if n.text? }
      position_ratio = total_text_length > 0 ? text_before_img.length.to_f / total_text_length : 1.0

      # Check if it's likely a social media icon by URL pattern
      is_social_url = src.match?(/linkedin|facebook|twitter|instagram|youtube|social|fbcdn|licdn|static\.licdn/)
      
      # Check if it's likely a social media icon by alt text
      is_social_alt = alt.match?(/linkedin|facebook|twitter|instagram|youtube|follow|connect/)
      
      # Check if image appears in latter half of email (signature area)
      is_in_signature_area = position_ratio > 0.5
      
      # Check if multiple images appear consecutively (common for social icon rows)
      has_sibling_images = idx > 0 || (idx < all_images.length - 1)
      
      # Mark as social icon if matches patterns
      if is_social_url || is_social_alt || (is_in_signature_area && has_sibling_images && idx > 0)
        existing_class = img["class"].to_s
        img["class"] = "#{existing_class} email-social-icon".strip
      end
    end
  end

  # Validates and sanitizes URL schemes in href and src attributes
  # Blocks dangerous schemes like javascript:, data:, vbscript:, etc.
  #
  # @param html [String] The HTML to sanitize
  # @return [String] HTML with dangerous URLs removed
  def sanitize_url_schemes(html)
    return html if html.blank?

    safe_schemes = %w[http https mailto]

    # Parse and sanitize href attributes
    html = html.gsub(/\bhref\s*=\s*["']([^"']*)["']/i) do |match|
      url = Regexp.last_match(1).to_s.strip.downcase
      scheme = url.split(":").first

      if url.start_with?("/", "#") || safe_schemes.include?(scheme)
        match
      else
        'href="#"'
      end
    end

    # Parse and sanitize src attributes
    html.gsub(/\bsrc\s*=\s*["']([^"']*)["']/i) do |match|
      url = Regexp.last_match(1).to_s.strip.downcase
      scheme = url.split(":").first

      if url.start_with?("/") || %w[http https].include?(scheme)
        match
      else
        'src=""'
      end
    end
  end

  # Re-injects sanitized styles that were extracted before Rails sanitization
  # Replaces data-se-style-id attributes with the corresponding style attributes
  #
  # @param html [String] The HTML with data-se-style-id markers
  # @param style_map [Hash] Map of style IDs to sanitized CSS strings
  # @return [String] HTML with styles re-injected
  def reinject_styles(html, style_map)
    return html if html.blank? || style_map.empty?

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)

    fragment.css("*[data-se-style-id]").each do |node|
      style_id = node["data-se-style-id"]
      safe_style = style_map[style_id]

      if safe_style.present?
        node["style"] = safe_style
      end

      # Always remove the marker attribute
      node.remove_attribute("data-se-style-id")
    end

    fragment.to_html
  rescue StandardError
    html
  end

  # Sanitizes inline style attributes to only allow safe CSS properties
  # Removes dangerous CSS like expressions, url() with javascript, etc.
  #
  # @param html [String] The HTML with style attributes
  # @return [String] HTML with sanitized style attributes
  def sanitize_inline_styles(html)
    return html if html.blank?

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)

    fragment.css("*[style]").each do |node|
      original_style = node["style"].to_s
      safe_style = extract_safe_styles(original_style)

      if safe_style.present?
        node["style"] = safe_style
      else
        node.remove_attribute("style")
      end
    end

    fragment.to_html
  rescue StandardError
    html
  end

  # Extracts only safe CSS properties from a style string
  # Filters out dangerous values like url(), expression(), javascript:
  #
  # @param style_string [String] The raw CSS style string
  # @return [String] Filtered CSS declarations
  def extract_safe_styles(style_string)
    return "" if style_string.blank?

    safe_declarations = style_string.split(";").filter_map do |declaration|
      property, value = declaration.split(":", 2).map(&:strip)
      next unless property.present? && value.present?

      # Normalize property name for comparison
      property_lower = property.downcase.gsub(/\s+/, "-")

      # Only keep safe properties
      next unless SAFE_STYLE_PROPERTIES.include?(property_lower)

      # Reject dangerous values
      value_lower = value.downcase
      next if value_lower.include?("url(") && !safe_url_in_style?(value)
      next if value_lower.include?("expression(")
      next if value_lower.include?("javascript:")
      next if value_lower.include?("vbscript:")
      next if value_lower.include?("behavior:")
      next if value_lower.include?("-moz-binding")

      "#{property}: #{value}"
    end

    safe_declarations.join("; ")
  end

  # Checks if a url() in CSS is safe (http/https only)
  #
  # @param value [String] The CSS value containing url()
  # @return [Boolean]
  def safe_url_in_style?(value)
    # Extract URL from url(...) or url("...") or url('...')
    urls = value.scan(/url\s*\(\s*['"]?([^'")]+)['"]?\s*\)/i).flatten
    urls.all? do |url|
      url.strip.downcase.start_with?("http://", "https://", "/")
    end
  end

  # Links or creates the email sender record
  #
  # @return [void]
  def link_or_create_sender
    return if email_sender_id.present? || from_email.blank?

    self.email_sender = EmailSender.find_or_create_from_email(from_email, from_name)
  end
end
