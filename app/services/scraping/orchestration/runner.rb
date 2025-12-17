# frozen_string_literal: true

module Scraping
  module Orchestration
    # Runs the scraping pipeline steps in order.
    class Runner
      def initialize(context)
        @context = context
      end

      # @return [Boolean] true if completed successfully
      def call
        steps.each do |step|
          outcome = step.call(@context)
          return true if outcome == :stop_success
          return false if outcome == :stop_failure
        end

        false
      rescue => e
        Support::AttemptLifecycle.log_error(@context, "Orchestration failed", e)
        @context.event_recorder&.record_failure(
          message: e.message,
          error_type: e.class.name,
          details: { backtrace: e.backtrace&.first(5) }
        )
        Support::AttemptLifecycle.fail!(@context, failed_step: "orchestration", error_message: e.message)
        raise
      end

      private

      def steps
        [
          Steps::DetectJobBoard.new,
          Steps::FetchHtml.new,
          Steps::RenderedFallback.new,
          Steps::NokogiriScrape.new,
          Steps::SelectorsExtract.new,
          Steps::ApiExtract.new,
          Steps::AiExtract.new
        ]
      end
    end
  end
end
