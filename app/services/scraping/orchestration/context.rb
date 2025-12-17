# frozen_string_literal: true

module Scraping
  module Orchestration
    # Shared state for a scraping orchestration run.
    class Context
      CONFIDENCE_THRESHOLD = 0.7

      attr_reader :job_listing, :attempt, :event_recorder, :started_at
      attr_accessor :detector, :board_type, :company_slug, :job_id
      attr_accessor :html_content, :cleaned_html, :fetch_mode

      def initialize(job_listing:, attempt:, event_recorder:)
        @job_listing = job_listing
        @attempt = attempt
        @event_recorder = event_recorder
        @started_at = Time.current

        @detector = nil
        @board_type = :unknown
        @company_slug = nil
        @job_id = nil

        @html_content = nil
        @cleaned_html = nil
        @fetch_mode = "static"
      end

      def confidence_threshold
        CONFIDENCE_THRESHOLD
      end
    end
  end
end
