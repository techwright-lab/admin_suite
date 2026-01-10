# frozen_string_literal: true

module Scraping
  # Classifies scraping failures into "retryable" vs "terminal/logical".
  #
  # We only want DLQ + retries for issues that can plausibly succeed on retry:
  # - transient network issues (timeouts, 5xx, connection resets)
  # - provider outages / Selenium hiccups
  # - unexpected exceptions (bugs)
  #
  # We do NOT want DLQ for "logical" failures like:
  # - low confidence extraction
  # - thin HTML / rendered shell pages (not enough content)
  # - 404/410 (resource missing)
  #
  # @example
  #   classifier = Scraping::FailureClassifierService.new(attempt)
  #   classifier.retryable? #=> true/false
  class FailureClassifierService
    # @param [ScrapingAttempt] scraping_attempt
    def initialize(scraping_attempt)
      @attempt = scraping_attempt
    end

    # @return [Boolean]
    def retryable?
      return false if logical_low_confidence?
      return false if logical_thin_html?
      return false if logical_http_not_found?

      # If we can’t confidently classify it as logical, default to retryable.
      true
    rescue
      true
    end

    private

    def logical_low_confidence?
      return false unless @attempt.failed_step.to_s == "ai_extraction"

      @attempt.error_message.to_s.match?(/\Alow confidence:/i) ||
        @attempt.error_message.to_s.match?(/extraction failed: low confidence/i)
    end

    def logical_thin_html?
      event = @attempt.scraping_events.where(event_type: :rendered_html_fetch).order(created_at: :desc).first
      output = event&.output_payload
      return false unless output.is_a?(Hash)

      output["rendered_shell"] == true || output["cleaned_text_length"].to_i < 300
    end

    def logical_http_not_found?
      return false unless @attempt.failed_step.to_s == "html_fetch"

      msg = @attempt.error_message.to_s
      msg.match?(/\AHTTP\s+404:/i) || msg.match?(/\AHTTP\s+410:/i) || msg.match?(/\AHTTP\s+403:/i)
    end
  end
end
