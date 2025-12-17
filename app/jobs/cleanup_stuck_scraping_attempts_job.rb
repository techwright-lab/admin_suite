# frozen_string_literal: true

# Background job to detect and clean up stuck scraping attempts
#
# Scraping attempts can get stuck in intermediate states (fetching, extracting)
# if the process hangs or crashes without proper error handling.
#
# This job runs periodically to:
# 1. Find attempts stuck in intermediate states for too long
# 2. Mark them as failed with appropriate error messages
# 3. Optionally retry or notify for manual review
#
# @example Run manually
#   CleanupStuckScrapingAttemptsJob.perform_now
#
# @example Schedule (add to config/recurring.yml for solid_queue)
#   cleanup_stuck_scraping_attempts:
#     class: CleanupStuckScrapingAttemptsJob
#     schedule: every 10 minutes
class CleanupStuckScrapingAttemptsJob < ApplicationJob
  queue_as :maintenance

  # How long an attempt can be in an intermediate state before considered stuck
  STUCK_THRESHOLD_MINUTES = 10

  # Intermediate states that should transition quickly
  INTERMEDIATE_STATES = %w[pending fetching extracting retrying].freeze

  def perform
    stuck_attempts = find_stuck_attempts
    return if stuck_attempts.empty?

    Rails.logger.info({
      event: "cleanup_stuck_attempts_started",
      count: stuck_attempts.count
    }.to_json)

    cleaned_count = 0
    stuck_attempts.find_each do |attempt|
      cleanup_attempt(attempt)
      cleaned_count += 1
    end

    Rails.logger.info({
      event: "cleanup_stuck_attempts_completed",
      cleaned_count: cleaned_count
    }.to_json)
  end

  private

  def find_stuck_attempts
    threshold = STUCK_THRESHOLD_MINUTES.minutes.ago

    ScrapingAttempt
      .where(status: INTERMEDIATE_STATES)
      .where("updated_at < ?", threshold)
      .order(updated_at: :asc)
  end

  def cleanup_attempt(attempt)
    # Determine which step was stuck
    last_event = attempt.scraping_events.order(created_at: :desc).first
    stuck_step = last_event&.event_type || attempt.status

    # Check if there's an incomplete event (started but not completed)
    incomplete_event = attempt.scraping_events.find_by(status: :started)
    if incomplete_event
      incomplete_event.update!(
        status: :failed,
        completed_at: Time.current,
        error_type: "StuckTimeout",
        error_message: "Step timed out after #{STUCK_THRESHOLD_MINUTES} minutes"
      )
    end

    # Mark the attempt as failed
    attempt.update!(
      status: :failed,
      failed_step: stuck_step,
      error_message: "Attempt stuck at '#{stuck_step}' for over #{STUCK_THRESHOLD_MINUTES} minutes - automatically cleaned up"
    )

    Rails.logger.warn({
      event: "stuck_attempt_cleaned",
      scraping_attempt_id: attempt.id,
      job_listing_id: attempt.job_listing_id,
      stuck_step: stuck_step,
      stuck_since: attempt.updated_at.iso8601
    }.to_json)

    # Notify for monitoring
    ExceptionNotifier.notify(
      StandardError.new("Stuck scraping attempt cleaned up"),
      {
        context: "stuck_attempt_cleanup",
        severity: "warning",
        scraping_attempt_id: attempt.id,
        job_listing_id: attempt.job_listing_id,
        stuck_step: stuck_step,
        stuck_duration_minutes: ((Time.current - attempt.updated_at) / 60).round
      }
    )
  end
end
