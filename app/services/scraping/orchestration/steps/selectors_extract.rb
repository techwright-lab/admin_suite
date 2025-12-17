# frozen_string_literal: true

module Scraping
  module Orchestration
    module Steps
      class SelectorsExtract < BaseStep
        def call(context)
          return continue if context.board_type.to_sym == :unknown

          selectors_result = context.event_recorder.record(
            :selectors_extraction,
            input: { board_type: context.board_type }
          ) do |event|
            extractor = Scraping::JobBoards::ExtractorFactory.build(context.board_type)
            result = extractor.extract(context.html_content)
            event.set_output(
              success: result[:success],
              confidence: result[:confidence],
              extracted_fields: result[:extracted_fields],
              missing_fields: result[:missing_fields],
              board_type: result[:board_type],
              extractor_kind: result[:extractor_kind]
            )

            Support::Observability.create_selectors_html_log(
              context,
              result,
              fetch_mode: context.fetch_mode,
              board_type: context.board_type,
              html_size: context.html_content.to_s.bytesize,
              cleaned_html_size: context.cleaned_html.to_s.bytesize
            )

            result
          end

          return continue unless selectors_result[:success] && selectors_result[:confidence].to_f >= context.confidence_threshold

          data = selectors_result[:data] || {}
          result_for_update = data.merge(
            extraction_method: "html",
            provider: selectors_result[:provider] || context.board_type.to_s,
            confidence: selectors_result[:confidence]
          )

          Support::JobListingUpdater.update_final!(context, result_for_update)
          context.event_recorder.record_simple(:data_update, status: :success, input: { source: "selectors" }, output: { confidence: selectors_result[:confidence] })
          Support::AttemptLifecycle.complete!(context, extraction_method: "html", provider: context.board_type.to_s, confidence: selectors_result[:confidence])
          context.event_recorder.record_completion(summary: { method: "html", confidence: selectors_result[:confidence], provider: context.board_type })
          stop_success
        end
      end
    end
  end
end
