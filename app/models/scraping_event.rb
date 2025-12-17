# frozen_string_literal: true

# ScrapingEvent model for tracking individual steps in the scraping pipeline
#
# Records each step of the extraction process (fetch, parse, extract) with
# timing, payloads, and status for complete observability.
#
# @example
#   event = ScrapingEvent.create!(
#     scraping_attempt: attempt,
#     event_type: :html_fetch,
#     step_order: 1,
#     status: :success,
#     duration_ms: 1500
#   )
class ScrapingEvent < ApplicationRecord
  EVENT_TYPES = [
    :permission_check,  # Robots.txt / rate limit check
    :job_board_detection, # Job board/ATS detection from URL
    :html_fetch,        # Fetching HTML content
    :js_heavy_detected, # Heuristic indicating JS-rendered content
    :rendered_html_fetch, # Selenium/Headless rendered HTML fetch
    :nokogiri_scrape,   # Preliminary HTML parsing
    :selectors_extraction, # Selectors-first extraction (job boards)
    :api_extraction,    # API-based extraction (Greenhouse, Lever)
    :ai_extraction,     # LLM-based extraction
    :data_update,       # Updating job listing with extracted data
    :completion,        # Successful completion
    :failure            # Pipeline failure
  ].freeze

  STATUSES = [
    :started,   # Step has begun
    :success,   # Step completed successfully
    :failed,    # Step failed
    :skipped    # Step was skipped
  ].freeze

  # Associations
  belongs_to :scraping_attempt
  belongs_to :job_listing, optional: true

  # Enums
  enum :event_type, {
    permission_check: "permission_check",
    job_board_detection: "job_board_detection",
    html_fetch: "html_fetch",
    js_heavy_detected: "js_heavy_detected",
    rendered_html_fetch: "rendered_html_fetch",
    nokogiri_scrape: "nokogiri_scrape",
    selectors_extraction: "selectors_extraction",
    api_extraction: "api_extraction",
    ai_extraction: "ai_extraction",
    data_update: "data_update",
    completion: "completion",
    failure: "failure"
  }

  enum :status, {
    started: 0,
    success: 1,
    failed: 2,
    skipped: 3
  }, default: :started

  # Validations
  validates :event_type, presence: true

  # Scopes
  scope :for_attempt, ->(attempt_id) { where(scraping_attempt_id: attempt_id) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :successful, -> { where(status: :success) }
  scope :failed, -> { where(status: :failed) }
  scope :in_order, -> { order(step_order: :asc, created_at: :asc) }
  scope :recent, -> { order(created_at: :desc) }

  # Returns formatted duration string
  #
  # @return [String] Formatted duration (e.g., "1.5s", "250ms")
  def formatted_duration
    return "N/A" if duration_ms.nil?

    if duration_ms < 1000
      "#{duration_ms}ms"
    else
      "#{(duration_ms / 1000.0).round(2)}s"
    end
  end

  # Returns a summary of the input payload
  #
  # @param [Integer] max_length Maximum length of summary
  # @return [String] Summary of input
  def input_summary(max_length = 100)
    return "No input" if input_payload.blank?

    summarize_payload(input_payload, max_length)
  end

  # Returns a summary of the output payload
  #
  # @param [Integer] max_length Maximum length of summary
  # @return [String] Summary of output
  def output_summary(max_length = 100)
    return "No output" if output_payload.blank?

    summarize_payload(output_payload, max_length)
  end

  # Returns the event type display name
  #
  # @return [String] Human-readable event type
  def event_type_display
    case event_type&.to_sym
    when :permission_check then "Permission Check"
    when :job_board_detection then "Job Board Detection"
    when :html_fetch then "HTML Fetch"
    when :js_heavy_detected then "JS-Heavy Detected"
    when :rendered_html_fetch then "Rendered HTML Fetch"
    when :nokogiri_scrape then "HTML Parse"
    when :selectors_extraction then "Selectors Extraction"
    when :api_extraction then "API Extraction"
    when :ai_extraction then "AI Extraction"
    when :data_update then "Data Update"
    when :completion then "Completion"
    when :failure then "Failure"
    else event_type&.titleize || "Unknown"
    end
  end

  # Returns icon name for the event type
  #
  # @return [String] Icon identifier
  def event_icon
    case event_type&.to_sym
    when :permission_check then "shield-check"
    when :job_board_detection then "tag"
    when :html_fetch then "cloud-download"
    when :js_heavy_detected then "sparkles"
    when :rendered_html_fetch then "globe-alt"
    when :nokogiri_scrape then "code"
    when :selectors_extraction then "adjustments-horizontal"
    when :api_extraction then "server"
    when :ai_extraction then "cpu"
    when :data_update then "database"
    when :completion then "check-circle"
    when :failure then "x-circle"
    else "circle"
    end
  end

  # Returns status badge color
  #
  # @return [String] Color class name
  def status_badge_color
    case status&.to_sym
    when :success then "success"
    when :failed then "danger"
    when :skipped then "neutral"
    when :started then "info"
    else "neutral"
    end
  end

  # Checks if this event has error details
  #
  # @return [Boolean] True if has error
  def has_error?
    error_message.present? || error_type.present?
  end

  # Returns extracted fields from output payload
  #
  # @return [Array<String>] List of field names
  def extracted_fields
    return [] unless output_payload.is_a?(Hash)

    output_payload["extracted_fields"] || output_payload.keys.select do |k|
      !%w[error confidence raw_response].include?(k)
    end
  end

  private

  # Summarizes a payload hash for display
  #
  # @param [Hash] payload The payload to summarize
  # @param [Integer] max_length Maximum length
  # @return [String] Summary
  def summarize_payload(payload, max_length)
    return payload.to_s.truncate(max_length) unless payload.is_a?(Hash)

    keys = payload.keys.first(5)
    summary = keys.map { |k| "#{k}: #{payload[k].to_s.truncate(20)}" }.join(", ")

    if payload.keys.length > 5
      summary += " (+#{payload.keys.length - 5} more)"
    end

    summary.truncate(max_length)
  end
end
