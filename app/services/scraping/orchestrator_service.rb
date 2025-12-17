# frozen_string_literal: true

module Scraping
  # Backwards-compatible entrypoint for job listing extraction.
  #
  # The actual pipeline lives under Scraping::Orchestration.
  class OrchestratorService
    attr_reader :job_listing, :attempt, :event_recorder

    def initialize(job_listing)
      @job_listing = job_listing
      @attempt = nil
      @event_recorder = nil
    end

    # @return [Boolean] true if extraction completed successfully
    def call
      return false unless job_listing.url.present?

      job_listing.save! if job_listing.new_record?

      @attempt = Scraping::Orchestration::Support::AttemptLifecycle.create_attempt!(job_listing)

      # If create_attempt! returns nil, a recent attempt just completed - no need to re-extract
      if @attempt.nil?
        Rails.logger.info({
          event: "extraction_skipped_recent_completion",
          job_listing_id: job_listing.id
        }.to_json)
        return true
      end

      @event_recorder = Scraping::EventRecorderService.new(@attempt, job_listing: job_listing)

      context = Scraping::Orchestration::Context.new(
        job_listing: job_listing,
        attempt: @attempt,
        event_recorder: @event_recorder
      )

      Scraping::Orchestration::Support::AttemptLifecycle.log_event(context, "extraction_started")

      Scraping::Orchestration::Runner.new(context).call
    end
  end
end
