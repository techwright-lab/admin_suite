# frozen_string_literal: true

module Scraping
  module Orchestration
    module Steps
      class ApiExtract < BaseStep
        def call(context)
          detector = context.detector
          return continue unless detector&.api_supported? && context.company_slug.present?

          unless Setting.api_population_enabled?
            context.event_recorder.record_skipped(:api_extraction, reason: "api_population_disabled", metadata: { board_type: context.board_type })
            return continue
          end

          api_result = context.event_recorder.record(
            :api_extraction,
            input: { board_type: context.board_type, company_slug: context.company_slug, job_id: context.job_id }
          ) do |event|
            result = fetch_api(context)
            if result
              event.set_output(
                success: result[:confidence].present? && result[:confidence] >= context.confidence_threshold,
                confidence: result[:confidence],
                provider: context.board_type,
                extracted_fields: result.keys
              )
            else
              event.set_output(success: false, error: "No result from API")
            end
            result
          end

          return continue unless api_result && api_result[:confidence] && api_result[:confidence] >= context.confidence_threshold

          context.event_recorder.record_simple(:data_update, status: :success, input: { source: "api" }, output: { confidence: api_result[:confidence] })
          Support::JobListingUpdater.update_final!(context, api_result.merge(extraction_method: "api"))
          context.event_recorder.record_completion(summary: { method: "api", confidence: api_result[:confidence], provider: context.board_type })
          Support::AttemptLifecycle.complete!(context, extraction_method: "api", provider: context.board_type.to_s, confidence: api_result[:confidence], model: api_result[:model], tokens_used: api_result[:tokens_used])
          stop_success
        rescue => e
          Support::AttemptLifecycle.log_error(context, "API extraction failed", e)
          ExceptionNotifier.notify(e, {
            context: "api_extraction",
            severity: "error",
            board_type: context.board_type,
            company_slug: context.company_slug,
            job_id: context.job_id,
            url: context.job_listing.url
          })
          continue
        end

        private

        def fetch_api(context)
          fetcher = case context.board_type.to_sym
          when :greenhouse
            ApiFetchers::GreenhouseFetcher.new
          when :lever
            ApiFetchers::LeverFetcher.new
          else
            nil
          end

          return nil unless fetcher

          fetcher.fetch(url: context.job_listing.url, company_slug: context.company_slug, job_id: context.job_id)
        end
      end
    end
  end
end
