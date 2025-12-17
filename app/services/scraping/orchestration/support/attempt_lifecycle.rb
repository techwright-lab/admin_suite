# frozen_string_literal: true

module Scraping
  module Orchestration
    module Support
      module AttemptLifecycle
        module_function

        # Creates a new scraping attempt, or returns existing recent one if still in progress
        #
        # Prevents duplicate attempts when:
        # - A timeout occurs and the job is re-queued
        # - Multiple calls happen in quick succession
        # - An attempt just completed (no need to re-extract)
        #
        # @param job_listing [JobListing] The job listing to create an attempt for
        # @param force [Boolean] Force create even if recent attempt exists
        # @return [ScrapingAttempt, nil] New or existing attempt, or nil if recently completed
        def create_attempt!(job_listing, force: false)
          unless force
            # Check for existing recent attempt that's still in progress (within last 2 minutes)
            recent_in_progress = job_listing.scraping_attempts
              .where(status: [ :pending, :fetching, :extracting, :retrying ])
              .where("created_at > ?", 2.minutes.ago)
              .order(created_at: :desc)
              .first

            if recent_in_progress
              Rails.logger.info({
                event: "reusing_existing_attempt",
                job_listing_id: job_listing.id,
                scraping_attempt_id: recent_in_progress.id,
                status: recent_in_progress.status
              }.to_json)
              return recent_in_progress
            end

            # Check for recently completed attempt (within last 2 minutes)
            # No need to re-extract if we just finished successfully
            recent_completed = job_listing.scraping_attempts
              .where(status: :completed)
              .where("created_at > ?", 2.minutes.ago)
              .order(created_at: :desc)
              .first

            if recent_completed
              Rails.logger.info({
                event: "skipping_attempt_recently_completed",
                job_listing_id: job_listing.id,
                scraping_attempt_id: recent_completed.id,
                completed_at: recent_completed.updated_at
              }.to_json)
              return nil
            end
          end

          job_listing.scraping_attempts.create!(
            url: job_listing.url,
            domain: extract_domain(job_listing.url),
            status: :pending
          )
        end

        def complete!(context, extraction_method:, provider:, confidence:, model: nil, tokens_used: nil)
          attempt = context.attempt
          return unless attempt

          # Ensure state machine is in a completable state.
          # Some completions happen via selectors/API without ever hitting the AI step,
          # so we may still be in :fetching here.
          attempt.start_fetch! if attempt.respond_to?(:may_start_fetch?) && attempt.may_start_fetch?
          attempt.start_extract! if attempt.respond_to?(:may_start_extract?) && attempt.may_start_extract?

          attempt.update(
            extraction_method: extraction_method,
            provider: provider,
            confidence_score: confidence,
            duration_seconds: Time.current - context.started_at,
            response_metadata: {
              model: model,
              tokens_used: tokens_used
            }
          )
          attempt.mark_completed!

          log_event(context, "extraction_completed", {
            confidence: confidence,
            duration: Time.current - context.started_at
          })
        end

        def fail!(context, failed_step:, error_message:)
          attempt = context.attempt
          return unless attempt

          attempt.update(
            failed_step: failed_step,
            error_message: error_message,
            duration_seconds: Time.current - context.started_at
          )
          attempt.mark_failed!

          log_event(context, "extraction_failed", { failed_step: failed_step, error: error_message })
        end

        def log_event(context, event_name, data = {})
          Rails.logger.info({
            event: event_name,
            job_listing_id: context.job_listing.id,
            scraping_attempt_id: context.attempt&.id,
            url: context.job_listing.url,
            domain: extract_domain(context.job_listing.url)
          }.merge(data).to_json)
        end

        def log_error(context, message, exception)
          Rails.logger.error({
            error: message,
            exception: exception.class.name,
            message: exception.message,
            backtrace: exception.backtrace&.first(5),
            job_listing_id: context.job_listing.id,
            scraping_attempt_id: context.attempt&.id,
            url: context.job_listing.url
          }.to_json)

          ExceptionNotifier.notify(exception, {
            context: "scraping_orchestration",
            severity: "error",
            error_message: message,
            job_listing_id: context.job_listing.id,
            scraping_attempt_id: context.attempt&.id,
            url: context.job_listing.url
          })
        end

        def extract_domain(url)
          URI.parse(url).host
        rescue
          "unknown"
        end
      end
    end
  end
end
