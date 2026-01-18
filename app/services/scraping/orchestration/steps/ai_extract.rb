# frozen_string_literal: true

require "timeout"

module Scraping
  module Orchestration
    module Steps
      class AiExtract < BaseStep
        # Hard timeout for AI extraction to prevent indefinite hangs
        # LLM API calls can take 30-60 seconds for large documents
        AI_EXTRACTION_TIMEOUT_SECONDS = 120

        # Custom error for AI extraction timeout
        class AiExtractionTimeoutError < StandardError; end

        def call(context)
          context.attempt.start_extract!

          ai_result = context.event_recorder.record(
            :ai_extraction,
            input: { html_size: context.html_content&.bytesize, cleaned_html_size: context.cleaned_html&.bytesize }
          ) do |event|
            # Wrap AI extraction in a timeout to prevent indefinite hangs
            result = Timeout.timeout(AI_EXTRACTION_TIMEOUT_SECONDS, AiExtractionTimeoutError) do
              Scraping::AiJobExtractorService.new(context.job_listing, scraping_attempt: context.attempt).extract(
                html_content: context.html_content,
                cleaned_html: context.cleaned_html
              )
            end
            event.set_output(
              success: result[:confidence].present? && result[:confidence] >= context.confidence_threshold,
              confidence: result[:confidence],
              provider: result[:provider],
              model: result[:model],
              tokens_used: result[:tokens_used],
              extracted_fields: result.keys.select { |k| result[k].present? },
              error: result[:error]
            )
            result
          end

          confidence = ai_result&.dig(:confidence) || 0.0
          has_useful_data = ai_result && (ai_result[:title].present? || ai_result[:company].present? || ai_result[:description].present?)

          if confidence >= context.confidence_threshold
            # High confidence - full success
            context.event_recorder.record_simple(:data_update, status: :success, input: { source: "ai" }, output: { confidence: confidence })
            Support::JobListingUpdater.update_final!(context, ai_result.merge(extraction_method: "ai"))
            context.event_recorder.record_completion(summary: { method: "ai", confidence: confidence, provider: ai_result[:provider], model: ai_result[:model] })
            Support::AttemptLifecycle.complete!(
              context,
              extraction_method: "ai",
              provider: ai_result[:provider],
              confidence: confidence,
              model: ai_result[:model],
              tokens_used: ai_result[:tokens_used]
            )
            return stop_success
          end

          # Low confidence - but still save whatever useful data we extracted
          # This ensures title/company are updated even if overall confidence is low
          if has_useful_data
            context.event_recorder.record_simple(:data_update, status: :success, input: { source: "ai", partial: true }, output: { confidence: confidence })
            Support::JobListingUpdater.update_final!(context, ai_result.merge(extraction_method: "ai"))
            Rails.logger.info({
              event: "low_confidence_data_saved",
              job_listing_id: context.job_listing.id,
              confidence: confidence,
              extracted_fields: ai_result.keys.select { |k| ai_result[k].present? }
            }.to_json)
          end

          context.event_recorder.record_failure(
            message: "Low confidence: #{confidence}",
            error_type: "low_confidence",
            details: { confidence: confidence, data_saved: has_useful_data }
          )
          Support::AttemptLifecycle.fail!(context, failed_step: "ai_extraction", error_message: "Low confidence: #{confidence}")
          stop_failure
        rescue AiExtractionTimeoutError => e
          Rails.logger.error("AI extraction timed out after #{AI_EXTRACTION_TIMEOUT_SECONDS}s for job_listing=#{context.job_listing.id}")
          notify_error(
            e,
            context: "ai_extraction_timeout",
            severity: "warning",
            url: context.job_listing.url,
            job_listing_id: context.job_listing.id,
            timeout_seconds: AI_EXTRACTION_TIMEOUT_SECONDS
          )
          Support::AttemptLifecycle.fail!(context, failed_step: "ai_extraction", error_message: "AI extraction timed out after #{AI_EXTRACTION_TIMEOUT_SECONDS} seconds")
          stop_failure
        rescue => e
          Support::AttemptLifecycle.log_error(context, "AI extraction failed", e)
          notify_error(
            e,
            context: "ai_extraction",
            severity: "error",
            url: context.job_listing.url,
            job_listing_id: context.job_listing.id
          )
          Support::AttemptLifecycle.fail!(context, failed_step: "ai_extraction", error_message: e.message)
          stop_failure
        end
      end
    end
  end
end
