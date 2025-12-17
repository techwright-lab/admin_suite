# frozen_string_literal: true

module Scraping
  module Orchestration
    module Steps
      class RenderedFallback < BaseStep
        def call(context)
          return continue unless Setting.js_rendering_enabled?
          return continue unless Support::Observability.js_heavy_page?(html_content: context.html_content, cleaned_html: context.cleaned_html)

          context.event_recorder.record_simple(
            :js_heavy_detected,
            status: :success,
            output: {
              text_length: context.cleaned_html.to_s.length,
              html_size: context.html_content.to_s.bytesize,
              board_type: context.board_type
            }
          )

          rendered_result = context.event_recorder.record(
            :rendered_html_fetch,
            input: { url: context.job_listing.url, board_type: context.board_type }
          ) do |event|
            result = Scraping::RenderedHtmlFetcherService.new(context.job_listing, scraping_attempt: context.attempt).call
            event.set_output(
              success: result[:success],
              html_size: result[:html_content]&.bytesize,
              cleaned_html_size: result[:cleaned_html]&.bytesize,
              error: result[:error],
              rendered: true,
              fetch_mode: "rendered"
            )
            result
          end

          if rendered_result[:success]
            context.html_content = rendered_result[:html_content]
            context.cleaned_html = rendered_result[:cleaned_html]
            context.fetch_mode = "rendered"
          end

          continue
        end
      end
    end
  end
end
