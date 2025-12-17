# frozen_string_literal: true

module Scraping
  module Orchestration
    module Steps
      class NokogiriScrape < BaseStep
        def call(context)
          scraping_result = context.event_recorder.record(
            :nokogiri_scrape,
            input: { html_size: context.html_content&.bytesize }
          ) do |event|
            extractor = Scraping::HtmlScrapingService.new(
              job_listing: context.job_listing,
              scraping_attempt: context.attempt,
              board_type: context.board_type&.to_s,
              fetch_mode: context.fetch_mode,
              extractor_kind: "generic_html_scraping",
              run_context: "orchestrator"
            )
            result = extractor.extract(context.html_content, context.job_listing.url)
            event.set_output(
              extracted_fields: result.keys,
              title: result[:title],
              company: result[:company_name],
              location: result[:location]
            )
            result
          end

          Support::JobListingUpdater.update_preliminary!(context, scraping_result) if scraping_result.any?
          continue
        rescue => e
          Support::AttemptLifecycle.log_error(context, "HTML scraping failed", e)
          continue
        end
      end
    end
  end
end
