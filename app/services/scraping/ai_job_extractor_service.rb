# frozen_string_literal: true

module Scraping
  # Service for AI-powered job listing extraction
  #
  # Uses configured LLM providers to extract structured data from HTML,
  # with automatic fallback to alternative providers on failure.
  # Supports idempotent retries by accepting pre-fetched HTML content.
  #
  # @example
  #   extractor = Scraping::AiJobExtractorService.new(job_listing, scraping_attempt)
  #   result = extractor.extract(html_content: cached_html)
  #   if result[:confidence] >= 0.7
  #     # Use extracted data
  #   end
  class AiJobExtractorService
    include Concerns::Loggable

    attr_reader :job_listing, :scraping_attempt, :url

    # Initialize the extractor
    #
    # @param [JobListing] job_listing The job listing
    # @param [ScrapingAttempt, nil] scraping_attempt Optional scraping attempt
    def initialize(job_listing, scraping_attempt: nil)
      @job_listing = job_listing
      @scraping_attempt = scraping_attempt
      @url = job_listing.url
    end

    # Extracts job data using AI providers with fallback
    #
    # @param [String, nil] html_content Pre-fetched HTML content (for idempotent retries)
    # @param [String, nil] cleaned_html Pre-cleaned HTML content
    # @return [Hash] Extracted job data with confidence score
    def extract(html_content: nil, cleaned_html: nil)
      log_event("ai_extraction_started")

      # Get HTML content (from parameter or fetch via service)
      if cleaned_html.present?
        html_for_extraction = cleaned_html
      elsif html_content.present?
        # Use Nokogiri cleaner for raw HTML
        cleaner = Scraping::NokogiriHtmlCleanerService.new
        html_for_extraction = cleaner.clean(html_content)
      else
        # Fetch via HtmlFetcherService (uses cache, which already has cleaned HTML)
        fetch_result = Scraping::HtmlFetcherService.new(@job_listing, scraping_attempt: @scraping_attempt).call
        unless fetch_result[:success]
          log_event("ai_extraction_failed", { error: fetch_result[:error] || "Failed to fetch HTML" })
          return { error: fetch_result[:error] || "Failed to fetch HTML", confidence: 0.0 }
        end
        html_for_extraction = fetch_result[:cleaned_html]
      end

      unless html_for_extraction.present?
        log_event("ai_extraction_failed", { error: "No HTML content available" })
        return { error: "No HTML content available", confidence: 0.0 }
      end

      # Try providers in order until one succeeds
      providers = provider_chain
      providers.each do |provider_name|
        begin
          result = extract_with_provider(provider_name, html_for_extraction)

          # Check for rate limit error
          if result && result[:rate_limit]
            log_event("ai_extraction_rate_limited", {
              provider: provider_name,
              retry_after: result[:retry_after]
            })

            # If we have retry_after, wait before trying next provider
            if result[:retry_after] && result[:retry_after] > 0
              wait_time = [ result[:retry_after], 60 ].min # Cap at 60 seconds
              sleep(wait_time)
            end

            # Continue to next provider (fallback)
            next
          end

          if result && result[:confidence] && result[:confidence] >= 0.7
            log_event("ai_extraction_succeeded", {
              provider: provider_name,
              confidence: result[:confidence]
            })
            return result
          else
            log_event("ai_extraction_low_confidence", {
              provider: provider_name,
              confidence: result[:confidence]
            })
          end
        rescue => e
          log_error("Provider #{provider_name} failed", e)

          # Notify exception with extraction context
          ExceptionNotifier.notify(e, {
            context: "ai_job_extraction",
            severity: "error",
            provider_name: provider_name,
            url: @url
          })

          next
        end
      end

      # All providers failed or returned low confidence
      log_event("ai_extraction_failed", {
        error: "All providers failed or returned low confidence"
      })
      {
        error: "All providers failed or returned low confidence",
        confidence: 0.0
      }
    end

    private


    # Returns the provider chain (primary + fallbacks)
    #
    # @return [Array<String>] Provider names in order
    def provider_chain
      # Ensure ProviderConfigHelper is loaded
      _ = LlmProviders::BaseProvider

      [
        LlmProviders::ProviderConfigHelper.default_provider
      ] + LlmProviders::ProviderConfigHelper.fallback_providers
    end

    # Extracts data using a specific provider
    #
    # @param [String] provider_name The provider name
    # @param [String] html_content The HTML content
    # @return [Hash] Extracted data
    def extract_with_provider(provider_name, html_content)
      provider = get_provider_instance(provider_name)

      unless provider.available?
        log_event("ai_extraction_provider_unavailable", { provider: provider_name })
        return nil
      end

      provider.extract_job_data(html_content, @url)
    end

    # Gets an instance of the specified provider
    #
    # @param [String] provider_name The provider name
    # @return [LlmProviders::BaseProvider] Provider instance
    def get_provider_instance(provider_name)
      provider = case provider_name.to_s.downcase
      when "openai"
        LlmProviders::OpenaiProvider.new
      when "anthropic"
        LlmProviders::AnthropicProvider.new
      when "ollama"
        LlmProviders::OllamaProvider.new
      else
        raise ArgumentError, "Unknown provider: #{provider_name}"
      end

      # Set logging context for observability
      provider.scraping_attempt = @scraping_attempt
      provider.job_listing = @job_listing

      provider
    end
  end
end
