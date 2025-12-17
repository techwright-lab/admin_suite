# frozen_string_literal: true

module Scraping
  module Orchestration
    module Support
      module Observability
        module_function

        JS_HEAVY_TEXT_THRESHOLD = 1500

        def js_heavy_page?(html_content:, cleaned_html:)
          text_len = cleaned_html.to_s.length
          return false if text_len >= JS_HEAVY_TEXT_THRESHOLD

          html = html_content.to_s
          spa_markers = [
            "__NEXT_DATA__",
            "data-reactroot",
            "id=\"app\"",
            "id=\"root\""
          ]
          spa_markers.any? { |m| html.include?(m) } || text_len < 200
        rescue
          false
        end

        def create_selectors_html_log(context, selectors_result, fetch_mode:, board_type:, html_size:, cleaned_html_size:)
          HtmlScrapingLog.create!(
            scraping_attempt: context.attempt,
            job_listing: context.job_listing,
            url: context.job_listing.url,
            domain: AttemptLifecycle.extract_domain(context.job_listing.url),
            html_size: html_size,
            cleaned_html_size: cleaned_html_size,
            duration_ms: nil,
            field_results: build_field_results_from_selectors(selectors_result),
            selectors_tried: selectors_result[:selectors_tried] || {},
            fetch_mode: fetch_mode,
            board_type: board_type.to_s,
            extractor_kind: selectors_result[:extractor_kind] || "job_board_selectors",
            run_context: "orchestrator"
          )
        rescue => e
          Rails.logger.warn("Failed to create HtmlScrapingLog for selectors extraction: #{e.message}")
          nil
        end

        def build_field_results_from_selectors(selectors_result)
          data = selectors_result[:data] || {}
          (HtmlScrapingLog::TRACKED_FIELDS + [ "job_role_title" ]).uniq.each_with_object({}) do |field, hash|
            key = field.to_s
            value = data[key.to_sym] || data[key]
            hash[key] = {
              "success" => value.present?,
              "value" => value.to_s.truncate(500),
              "selectors_tried" => Array(selectors_result.dig(:selectors_tried, key))
            }
          end
        end
      end
    end
  end
end
