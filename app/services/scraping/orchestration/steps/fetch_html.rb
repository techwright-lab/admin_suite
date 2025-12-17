# frozen_string_literal: true

module Scraping
  module Orchestration
    module Steps
      class FetchHtml < BaseStep
        def call(context)
          context.attempt.start_fetch!

          html_result = context.event_recorder.record(:html_fetch, input: { url: context.job_listing.url }) do |event|
            result = Scraping::HtmlFetcherService.new(context.job_listing, scraping_attempt: context.attempt).call
            event.set_output(
              success: result[:success],
              html_size: result[:html_content]&.bytesize,
              cleaned_html_size: result[:cleaned_html]&.bytesize,
              cached: result[:from_cache],
              http_status: result[:http_status],
              error: result[:error]
            )
            result
          end

          unless html_result[:success]
            context.event_recorder.record_failure(message: html_result[:error], error_type: "html_fetch_failed")
            Support::AttemptLifecycle.fail!(context, failed_step: "html_fetch", error_message: html_result[:error])
            return stop_failure
          end

          context.html_content = html_result[:html_content]
          context.cleaned_html = html_result[:cleaned_html]
          context.fetch_mode = "static"

          continue
        end
      end
    end
  end
end
