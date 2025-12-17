# frozen_string_literal: true

# Background job to scrape job listing details from a URL
#
# Uses the Scraping::OrchestratorService to extract data via API or AI.
# Implements automatic retries with exponential backoff and DLQ handling.
class ScrapeJobListingJob < ApplicationJob
  queue_as :default

  # Don't retry on serialization errors
  discard_on ActiveJob::DeserializationError

  # Note: We use manual retry logic instead of retry_on to prevent
  # exponential job growth. Retries are handled via ScrapingAttempt
  # and manual perform_later scheduling with attempt tracking.

  # Scrape job listing details using the orchestration service
  #
  # Supports smart retries using cached HTML when available.
  #
  # @param [JobListing] job_listing The job listing to scrape
  # @param [Integer, nil] scraping_attempt_id Optional scraping attempt ID for retries
  def perform(job_listing, scraping_attempt_id: nil)
    return unless job_listing.url.present?

    # If we have a scraping attempt ID, this is a retry - use RetryService
    if scraping_attempt_id
      attempt = ScrapingAttempt.find_by(id: scraping_attempt_id)
      if attempt && (attempt.failed? || attempt.retrying?)
        retry_with_service(attempt)
        return
      end
    end

    # Use the orchestrator service for extraction
    orchestrator = Scraping::OrchestratorService.new(job_listing)
    success = orchestrator.call

    if success
      Rails.logger.info({
        event: "job_scraping_succeeded",
        job_listing_id: job_listing.id,
        url: job_listing.url
      }.to_json)

      # Job listing details may have changed; recompute fit scores for dependent items.
      RecomputeFitAssessmentsForJobListingJob.perform_later(job_listing.id)
    else
      handle_extraction_failure(job_listing)
    end
  rescue => e
    # Log the error with full context
    Rails.logger.error({
      event: "job_scraping_error",
      job_listing_id: job_listing.id,
      url: job_listing.url,
      error: e.class.name,
      message: e.message,
      backtrace: e.backtrace&.first(5)
    }.to_json)

    # Handle failure and don't re-raise to prevent ActiveJob retry
    handle_extraction_failure(job_listing)
  end

  private

  # Retries extraction using RetryService with cached HTML
  #
  # @param [ScrapingAttempt] attempt The failed attempt
  def retry_with_service(attempt)
    retry_service = Scraping::RetryService.new(attempt)

    # Determine which step to retry based on failed_step
    result = case attempt.failed_step
    when "html_fetch"
      retry_service.retry_html_fetch
    when "api_extraction", "ai_extraction"
      retry_service.retry_extraction
    else
      # Unknown step or orchestration failure - retry full
      retry_service.retry_full
    end

    if result[:success]
      Rails.logger.info({
        event: "job_scraping_retry_succeeded",
        scraping_attempt_id: attempt.id,
        job_listing_id: attempt.job_listing_id,
        failed_step: attempt.failed_step
      }.to_json)
    else
      handle_retry_failure(attempt)
    end
  rescue => e
    Rails.logger.error({
      event: "job_scraping_retry_error",
      scraping_attempt_id: attempt.id,
      job_listing_id: attempt.job_listing_id,
      error: e.class.name,
      message: e.message
    }.to_json)
    handle_retry_failure(attempt)
    # Don't re-raise to prevent ActiveJob retry
  end

  # Handles extraction failure and schedules retries
  #
  # @param [JobListing] job_listing The job listing
  def handle_extraction_failure(job_listing)
    attempt = job_listing.scraping_attempts.order(created_at: :desc).first

    if attempt
      # Use retry_count from attempt, not executions (which is from ActiveJob)
      current_retry_count = attempt.retry_count || 0

      # After 3 attempts, send to DLQ
      if current_retry_count >= 3
        attempt.send_to_dlq!
        notify_admin_of_dlq(attempt)

        Rails.logger.error({
          event: "job_scraping_sent_to_dlq",
          job_listing_id: job_listing.id,
          scraping_attempt_id: attempt.id,
          url: job_listing.url,
          failed_step: attempt.failed_step,
          retry_count: current_retry_count
        }.to_json)
      else
        # Increment retry count
        attempt.update(retry_count: current_retry_count + 1)
        attempt.retry_attempt!

        # Schedule retry with attempt ID for smart retry
        ScrapeJobListingJob.perform_later(job_listing, scraping_attempt_id: attempt.id)

        Rails.logger.warn({
          event: "job_scraping_retry_scheduled",
          job_listing_id: job_listing.id,
          scraping_attempt_id: attempt.id,
          url: job_listing.url,
          failed_step: attempt.failed_step,
          retry_count: current_retry_count + 1,
          max_attempts: 3
        }.to_json)
      end
    end

    # Don't re-raise - we handle retries manually to prevent ActiveJob retry
  end

  # Handles retry failure
  #
  # @param [ScrapingAttempt] attempt The failed attempt
  def handle_retry_failure(attempt)
    current_retry_count = attempt.retry_count || 0

    if current_retry_count >= 3
      attempt.send_to_dlq!
      notify_admin_of_dlq(attempt)

      Rails.logger.error({
        event: "job_scraping_retry_sent_to_dlq",
        scraping_attempt_id: attempt.id,
        job_listing_id: attempt.job_listing_id,
        failed_step: attempt.failed_step,
        retry_count: current_retry_count
      }.to_json)
    else
      # Increment retry count
      attempt.update(retry_count: current_retry_count + 1)
      attempt.retry_attempt!
      ScrapeJobListingJob.perform_later(attempt.job_listing, scraping_attempt_id: attempt.id)

      Rails.logger.warn({
        event: "job_scraping_retry_rescheduled",
        scraping_attempt_id: attempt.id,
        job_listing_id: attempt.job_listing_id,
        failed_step: attempt.failed_step,
        retry_count: current_retry_count + 1
      }.to_json)
    end

    # Don't re-raise - we handle retries manually to prevent ActiveJob retry
  end

  # Notifies admin of items in the DLQ
  #
  # @param [ScrapingAttempt] attempt The failed attempt
  def notify_admin_of_dlq(attempt)
    # TODO: Implement admin notification
    # Could send email, Slack message, or other notification
    Rails.logger.info({
      event: "admin_notification_sent",
      scraping_attempt_id: attempt.id,
      job_listing_id: attempt.job_listing_id,
      notification_type: "dlq"
    }.to_json)
  end
end
