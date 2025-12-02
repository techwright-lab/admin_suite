# frozen_string_literal: true

module Scraping
  # Service for retrying failed scraping attempts
  #
  # Provides idempotent retry logic for individual steps, leveraging
  # cached HTML when available to avoid re-fetching.
  #
  # @example
  #   retry_service = Scraping::RetryService.new(scraping_attempt)
  #   result = retry_service.retry_html_fetch
  #   result = retry_service.retry_extraction
  #   result = retry_service.retry_full
  class RetryService
    attr_reader :scraping_attempt, :job_listing

    # Initialize the retry service
    #
    # @param [ScrapingAttempt] scraping_attempt The failed scraping attempt
    def initialize(scraping_attempt)
      @scraping_attempt = scraping_attempt
      @job_listing = scraping_attempt.job_listing
    end

    # Retries HTML fetching step
    #
    # @return [Hash] Result hash with success status
    def retry_html_fetch
      return error_result("Attempt is not in a retryable state") unless can_retry_html_fetch?

      @scraping_attempt.retry_attempt! if @scraping_attempt.failed?
      @scraping_attempt.start_fetch!

      fetcher = HtmlFetcherService.new(@job_listing, scraping_attempt: @scraping_attempt)
      result = fetcher.call

      if result[:success]
        # Link cached data to this attempt
        result[:cached_data]&.update(scraping_attempt: @scraping_attempt) if result[:cached_data]
        success_result("HTML fetch succeeded", result)
      else
        @scraping_attempt.update(failed_step: "html_fetch", error_message: result[:error])
        @scraping_attempt.mark_failed!
        error_result(result[:error] || "HTML fetch failed")
      end
    rescue => e
      @scraping_attempt.update(failed_step: "html_fetch", error_message: e.message)
      @scraping_attempt.mark_failed!
      error_result(e.message)
    end

    # Retries extraction step (AI or API) using cached HTML
    #
    # @return [Hash] Result hash with success status
    def retry_extraction
      return error_result("Attempt is not in a retryable state") unless can_retry_extraction?

      # Get cached HTML if available
      cached_data = @scraping_attempt.cached_html_data
      unless cached_data
        return error_result("No cached HTML available for retry")
      end

      @scraping_attempt.retry_attempt! if @scraping_attempt.failed?
      @scraping_attempt.start_extract!

      # Try API extraction first if applicable
      detector = Scraping::JobBoardDetectorService.new(@job_listing.url)
      if detector.api_supported? && detector.company_slug.present?
        api_result = try_api_extraction(detector.detect, detector.company_slug, detector.job_id)
        if api_result && api_result[:confidence] && api_result[:confidence] >= 0.7
          update_job_listing(api_result)
          complete_attempt(api_result)
          return success_result("API extraction succeeded", api_result)
        end
      end

      # Try AI extraction with cached HTML
      ai_result = try_ai_extraction_with_cache(cached_data)
      if ai_result && ai_result[:confidence] && ai_result[:confidence] >= 0.7
        update_job_listing(ai_result)
        complete_attempt(ai_result)
        success_result("AI extraction succeeded", ai_result)
      else
        @scraping_attempt.update(failed_step: "ai_extraction", error_message: "Low confidence: #{ai_result[:confidence] || 0.0}")
        @scraping_attempt.mark_failed!
        error_result("Extraction failed: Low confidence")
      end
    rescue => e
      @scraping_attempt.update(failed_step: "ai_extraction", error_message: e.message)
      @scraping_attempt.mark_failed!
      error_result(e.message)
    end

    # Retries the entire process from scratch
    #
    # @return [Hash] Result hash with success status
    def retry_full
      orchestrator = OrchestratorService.new(@job_listing)
      success = orchestrator.call

      if success
        success_result("Full retry succeeded")
      else
        error_result("Full retry failed")
      end
    end

    private

    # Checks if HTML fetch can be retried
    #
    # @return [Boolean] True if can retry
    def can_retry_html_fetch?
      @scraping_attempt.failed? || @scraping_attempt.retrying?
    end

    # Checks if extraction can be retried
    #
    # @return [Boolean] True if can retry
    def can_retry_extraction?
      (@scraping_attempt.failed? || @scraping_attempt.retrying?) &&
        (@scraping_attempt.ai_extraction_failed? || @scraping_attempt.api_extraction_failed?)
    end

    # Tries API extraction
    #
    # @param [Symbol] board_type The board type
    # @param [String] company_slug Company identifier
    # @param [String] job_id Job identifier
    # @return [Hash, nil] Extracted data or nil
    def try_api_extraction(board_type, company_slug, job_id)
      fetcher = get_api_fetcher(board_type)
      return nil unless fetcher

      fetcher.fetch(
        url: @job_listing.url,
        company_slug: company_slug,
        job_id: job_id
      )
    rescue => e
      Rails.logger.error("API extraction retry failed: #{e.message}")
      nil
    end

    # Gets the appropriate API fetcher for a board type
    #
    # @param [Symbol] board_type The board type
    # @return [ApiFetchers::BaseFetcher, nil] Fetcher instance or nil
    def get_api_fetcher(board_type)
      case board_type
      when :greenhouse
        ApiFetchers::GreenhouseFetcher.new
      when :lever
        ApiFetchers::LeverFetcher.new
      else
        nil
      end
    end

    # Tries AI extraction with cached HTML
    #
    # @param [ScrapedJobListingData] cached_data The cached HTML data
    # @return [Hash] Extracted data
    def try_ai_extraction_with_cache(cached_data)
      extractor = AiJobExtractorService.new(@job_listing, scraping_attempt: @scraping_attempt)
      extractor.extract(
        html_content: cached_data.html_content,
        cleaned_html: cached_data.cleaned_html
      )
    rescue => e
      Rails.logger.error("AI extraction retry failed: #{e.message}")
      { error: e.message, confidence: 0.0 }
    end

    # Updates the job listing with extracted data
    #
    # @param [Hash] result The extracted data
    def update_job_listing(result)
      @job_listing.update(
        title: result[:title] || @job_listing.title,
        description: result[:description] || @job_listing.description,
        requirements: result[:requirements] || @job_listing.requirements,
        responsibilities: result[:responsibilities] || @job_listing.responsibilities,
        salary_min: result[:salary_min] || @job_listing.salary_min,
        salary_max: result[:salary_max] || @job_listing.salary_max,
        salary_currency: result[:salary_currency] || @job_listing.salary_currency,
        equity_info: result[:equity_info] || @job_listing.equity_info,
        benefits: result[:benefits] || @job_listing.benefits,
        perks: result[:perks] || @job_listing.perks,
        location: result[:location] || @job_listing.location,
        remote_type: result[:remote_type] || @job_listing.remote_type,
        custom_sections: result[:custom_sections] || @job_listing.custom_sections,
        scraped_data: build_scraped_metadata(result)
      )
    end

    # Builds scraped metadata for storage
    #
    # @param [Hash] result The extraction result
    # @return [Hash] Metadata hash
    def build_scraped_metadata(result)
      {
        status: "completed",
        extraction_method: result[:extraction_method] || "ai",
        provider: result[:provider],
        model: result[:model],
        confidence_score: result[:confidence],
        tokens_used: result[:tokens_used],
        extracted_at: Time.current.iso8601,
        retried: true
      }
    end

    # Completes the attempt successfully
    #
    # @param [Hash] result The extraction result
    def complete_attempt(result)
      @scraping_attempt.update(
        extraction_method: result[:extraction_method] || "ai",
        provider: result[:provider],
        confidence_score: result[:confidence],
        duration_seconds: Time.current - @scraping_attempt.created_at,
        response_metadata: {
          model: result[:model],
          tokens_used: result[:tokens_used]
        }
      )
      @scraping_attempt.mark_completed!
    end

    # Returns a success result hash
    #
    # @param [String] message Success message
    # @param [Hash] data Additional data
    # @return [Hash] Success result
    def success_result(message, data = {})
      {
        success: true,
        message: message
      }.merge(data)
    end

    # Returns an error result hash
    #
    # @param [String] error_message The error message
    # @return [Hash] Error result
    def error_result(error_message)
      {
        success: false,
        error: error_message
      }
    end
  end
end

