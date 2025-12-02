# frozen_string_literal: true

module Scraping
  module Concerns
    # Concern for consistent structured logging across scraping services
    #
    # Provides standardized logging methods that include service context
    # and job listing information for better traceability.
    #
    # @example
    #   class MyService
    #     include Scraping::Concerns::Loggable
    #
    #     def initialize(job_listing, scraping_attempt: nil)
    #       @job_listing = job_listing
    #       @scraping_attempt = scraping_attempt
    #       @url = job_listing.url
    #     end
    #
    #     def call
    #       log_event("operation_started")
    #       # ... do work
    #       log_event("operation_completed", { result: "success" })
    #     end
    #   end
    module Loggable
      # Logs a structured event
      #
      # @param [String] event_name The event name
      # @param [Hash] data Additional event data
      def log_event(event_name, data = {})
        base_data = {
          event: event_name,
          service: self.class.name,
          job_listing_id: @job_listing&.id,
          scraping_attempt_id: @scraping_attempt&.id,
          url: @url || @job_listing&.url
        }
        Rails.logger.info(base_data.merge(data).to_json)
      end

      # Logs an error with optional exception details
      #
      # @param [String] message The error message
      # @param [Exception, nil] exception Optional exception object
      def log_error(message, exception = nil)
        error_data = {
          error: message,
          service: self.class.name,
          job_listing_id: @job_listing&.id,
          scraping_attempt_id: @scraping_attempt&.id,
          url: @url || @job_listing&.url
        }

        if exception
          error_data.merge!(
            exception: exception.class.name,
            message: exception.message,
            backtrace: exception.backtrace&.first(5)
          )
        end

        Rails.logger.error(error_data.to_json)
      end
    end
  end
end

