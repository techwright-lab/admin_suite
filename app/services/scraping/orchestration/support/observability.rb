# frozen_string_literal: true

module Scraping
  module Orchestration
    module Support
      module Observability
        module_function

        JS_HEAVY_TEXT_THRESHOLD = 1500

        # Returns a diagnosis for whether a page appears JS-heavy, along with the signals used.
        #
        # @param html_content [String, nil]
        # @param cleaned_html [String, nil]
        # @return [Hash]
        def js_heavy_diagnosis(html_content:, cleaned_html:)
          text_len = cleaned_html.to_s.length
          html = html_content.to_s

          spa_markers = [
            "__NEXT_DATA__",
            "data-reactroot",
            "id=\"app\"",
            "id=\"root\""
          ]

          found_markers = spa_markers.select { |m| html.include?(m) }

          js_heavy =
            if text_len >= JS_HEAVY_TEXT_THRESHOLD
              false
            else
              found_markers.any? || text_len < 200
            end

          reason =
            if text_len >= JS_HEAVY_TEXT_THRESHOLD
              "text_above_threshold"
            elsif found_markers.any?
              "spa_marker_detected"
            elsif text_len < 200
              "very_low_text"
            else
              "below_threshold"
            end

          {
            js_heavy: js_heavy,
            reason: reason,
            text_length: text_len,
            threshold: JS_HEAVY_TEXT_THRESHOLD,
            html_size: html.bytesize,
            spa_markers_found: found_markers
          }
        rescue => e
          {
            js_heavy: false,
            reason: "diagnosis_error",
            error: e.message
          }
        end

        def js_heavy_page?(html_content:, cleaned_html:)
          js_heavy_diagnosis(html_content: html_content, cleaned_html: cleaned_html)[:js_heavy]
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
