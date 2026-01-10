# frozen_string_literal: true

module Scraping
  module Orchestration
    module Steps
      class RenderedFallback < BaseStep
        def call(context)
          diagnosis = Support::Observability.js_heavy_diagnosis(html_content: context.html_content, cleaned_html: context.cleaned_html)

          unless Setting.js_rendering_enabled?
            context.event_recorder.record_simple(
              :js_heavy_detected,
              status: :skipped,
              output: diagnosis.merge(
                js_rendering_enabled: false,
                triggered: false,
                skipped_reason: "js_rendering_disabled",
                board_type: context.board_type
              )
            )
            return continue
          end

          unless diagnosis[:js_heavy]
            context.event_recorder.record_simple(
              :js_heavy_detected,
              status: :skipped,
              output: diagnosis.merge(
                js_rendering_enabled: true,
                triggered: false,
                skipped_reason: "not_js_heavy",
                board_type: context.board_type,
                fetch_mode: context.fetch_mode
              )
            )
            return continue
          end

          context.event_recorder.record_simple(
            :js_heavy_detected,
            status: :success,
            output: {
              **diagnosis,
              js_rendering_enabled: true,
              triggered: true,
              board_type: context.board_type,
              fetch_mode: context.fetch_mode
            }
          )

          rendered_result = context.event_recorder.record(
            :rendered_html_fetch,
            input: { url: context.job_listing.url, board_type: context.board_type }
          ) do |event|
            result = Scraping::RenderedHtmlFetcherService.new(context.job_listing, scraping_attempt: context.attempt).call
            rendered_shell =
              result[:success] &&
                (result[:cleaned_text_length].to_i < 500 || result[:selector_found] != true)

            event.set_output(
              success: result[:success],
              html_size: result[:html_content]&.bytesize,
              cleaned_html_size: result[:cleaned_html]&.bytesize,
              cleaned_text_length: result[:cleaned_text_length],
              error: result[:error],
              rendered: true,
              fetch_mode: "rendered",
              trigger_reason: diagnosis[:reason],
              selector_found: result[:selector_found],
              found_selectors: result[:found_selectors],
              selector_wait_ms: result[:selector_wait_ms],
              iframe_used: result[:iframe_used],
              rendered_shell: rendered_shell
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
