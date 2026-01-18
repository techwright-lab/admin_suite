# frozen_string_literal: true

module Scraping
  module Orchestration
    module Steps
      class ApiExtract < BaseStep
        def call(context)
          detector = context.detector
          return continue unless detector&.api_supported? && context.company_slug.present?

          unless api_population_enabled_for?(context)
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

          api_result = maybe_postprocess_with_ai(context, api_result)

          context.event_recorder.record_simple(:data_update, status: :success, input: { source: "api" }, output: { confidence: api_result[:confidence] })
          Support::JobListingUpdater.update_final!(context, api_result.merge(extraction_method: "api"))
          context.event_recorder.record_completion(summary: { method: "api", confidence: api_result[:confidence], provider: context.board_type })
          Support::AttemptLifecycle.complete!(context, extraction_method: "api", provider: context.board_type.to_s, confidence: api_result[:confidence], model: api_result[:model], tokens_used: api_result[:tokens_used])
          stop_success
        rescue => e
          Support::AttemptLifecycle.log_error(context, "API extraction failed", e)
          notify_error(
            e,
            context: "api_extraction",
            severity: "error",
            board_type: context.board_type,
            company_slug: context.company_slug,
            job_id: context.job_id,
            url: context.job_listing.url
          )
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

        def api_population_enabled_for?(context)
          # Greenhouse "boards API" is public (no API key) and should be allowed even when
          # generic API population is disabled due to missing credentials.
          return true if context.board_type.to_s == "greenhouse" && Setting.greenhouse_enabled?

          Setting.api_population_enabled?
        end

        def maybe_postprocess_with_ai(context, api_result)
          return api_result unless context.board_type.to_s == "greenhouse"
          return api_result unless api_result[:description].present?

          # Only run if we have gaps that the LLM can fill (compensation/interview process/lists).
          missing_salary = api_result[:salary_min].blank? && api_result[:salary_max].blank?
          missing_lists = api_result[:requirements].blank? && api_result[:responsibilities].blank?
          likely_has_comp = api_result[:description].to_s.match?(/compensation|salary|usd|eur|\$\s*\d/i)

          return api_result unless missing_salary || missing_lists || likely_has_comp

          post = Scraping::AiJobPostProcessorService.new(context.job_listing, scraping_attempt: context.attempt).run(
            content_html: api_result[:description],
            url: context.job_listing.url
          )

          return api_result if post[:confidence].to_f <= 0.0

          custom_sections = (api_result[:custom_sections] || {}).merge(
            "job_markdown" => post[:job_markdown].presence,
            "compensation_text" => post[:compensation_text].presence,
            "interview_process" => post[:interview_process].presence
          ).compact

          {
            **api_result,
            salary_min: post[:salary_min].presence || api_result[:salary_min],
            salary_max: post[:salary_max].presence || api_result[:salary_max],
            salary_currency: post[:salary_currency].presence || api_result[:salary_currency],
            requirements: bullets_to_text(post[:requirements_bullets]).presence || api_result[:requirements],
            responsibilities: bullets_to_text(post[:responsibilities_bullets]).presence || api_result[:responsibilities],
            benefits: bullets_to_text(post[:benefits_bullets]).presence || api_result[:benefits],
            perks: bullets_to_text(post[:perks_bullets]).presence || api_result[:perks],
            custom_sections: custom_sections
          }
        rescue => e
          Support::AttemptLifecycle.log_error(context, "AI postprocess skipped", e)
          api_result
        end

        def bullets_to_text(items)
          arr = Array(items).map(&:to_s).map(&:strip).reject(&:blank?)
          return "" if arr.empty?
          arr.map { |i| "- #{i}" }.join("\n")
        end
      end
    end
  end
end
