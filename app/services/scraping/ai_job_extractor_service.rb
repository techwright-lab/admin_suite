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
    # @param job_listing [JobListing] The job listing
    # @param scraping_attempt [ScrapingAttempt, nil] Optional scraping attempt
    def initialize(job_listing, scraping_attempt: nil)
      @job_listing = job_listing
      @scraping_attempt = scraping_attempt
      @url = job_listing.url
    end

    # Extracts job data using AI providers with fallback
    #
    # @param html_content [String, nil] Pre-fetched HTML content (for idempotent retries)
    # @param cleaned_html [String, nil] Pre-cleaned HTML content
    # @return [Hash] Extracted job data with confidence score
    def extract(html_content: nil, cleaned_html: nil)
      log_event("ai_extraction_started")

      html_for_extraction = get_html_content(html_content, cleaned_html)
      return extraction_error("No HTML content available") unless html_for_extraction.present?

      prompt = build_extraction_prompt(html_for_extraction)
      extract_with_providers(prompt, html_for_extraction.bytesize)
    end

    private

    def get_html_content(html_content, cleaned_html)
      if cleaned_html.present?
        cleaned_html
      elsif html_content.present?
        Scraping::NokogiriHtmlCleanerService.new.clean(html_content)
      else
        fetch_html_content
      end
    end

    def fetch_html_content
      fetch_result = Scraping::HtmlFetcherService.new(@job_listing, scraping_attempt: @scraping_attempt).call
      unless fetch_result[:success]
        log_event("ai_extraction_failed", { error: fetch_result[:error] || "Failed to fetch HTML" })
        return nil
      end
      fetch_result[:cleaned_html]
    end

    def extract_with_providers(prompt, html_size)
      provider_chain.each do |provider_name|
        result = try_provider(provider_name, prompt, html_size)
        if result && result[:confidence] && result[:confidence] >= 0.7
          return result.merge(prompt_used: prompt)
        elsif result && result[:confidence]
          # Return low confidence result with prompt for logging
          return result.merge(prompt_used: prompt)
        end
      end

      extraction_error("All providers failed or returned low confidence")
    end

    def try_provider(provider_name, prompt, html_size)
      provider = get_provider_instance(provider_name)
      prompt_template = Ai::JobExtractionPrompt.active_prompt
      system_message = prompt_template&.system_prompt.presence || Ai::JobExtractionPrompt.default_system_prompt

      unless provider.available?
        log_event("ai_extraction_provider_unavailable", { provider: provider_name })
        return nil
      end

      result = provider.run(prompt, system_message: system_message)

      if result[:rate_limit]
        handle_rate_limit(provider_name, result)
        return nil
      end

      if result[:error]
        log_event("ai_extraction_failed", { provider: provider_name, error: result[:error] })
        return nil
      end

      parsed = parse_response(result[:content])
      log_extraction(provider_name, result, parsed, html_size, prompt: prompt)

      build_extraction_result(parsed, result, provider_name)
    rescue => e
      log_error("Provider #{provider_name} failed", e)
      notify_extraction_error(e, provider_name)
      nil
    end

    def handle_rate_limit(provider_name, result)
      log_event("ai_extraction_rate_limited", {
        provider: provider_name,
        retry_after: result[:retry_after]
      })

      if result[:retry_after] && result[:retry_after] > 0
        wait_time = [ result[:retry_after], 60 ].min
        sleep(wait_time)
      end
    end

    def build_extraction_result(parsed, result, provider_name)
      parsed.merge(
        provider: provider_name,
        model: result[:model],
        input_tokens: result[:input_tokens],
        output_tokens: result[:output_tokens],
        raw_response: result[:content]
      )
    end

    def log_extraction(provider_name, result, parsed, html_size, prompt: nil)
      confidence = parsed[:confidence] || 0.0

      if confidence >= 0.7
        log_event("ai_extraction_succeeded", { provider: provider_name, confidence: confidence })
      else
        log_event("ai_extraction_low_confidence", { provider: provider_name, confidence: confidence })
      end

      log_extraction_result(result, parsed, html_size, prompt: prompt)
    end

    def log_extraction_result(result, parsed, html_size, prompt: nil)
      return unless @job_listing

      prompt_template = Ai::JobExtractionPrompt.active_prompt

      logger = Ai::ApiLoggerService.new(
        operation_type: :job_extraction,
        loggable: @job_listing,
        provider: result[:provider],
        model: result[:model],
        llm_prompt: prompt_template
      )

      logger.record_result(
        parsed.merge(provider: result[:provider], model: result[:model]),
        latency_ms: result[:latency_ms] || 0,
        content_size: html_size,
        prompt: prompt
      )
    rescue => e
      Rails.logger.warn("Failed to log extraction result: #{e.message}")
    end

    def extraction_error(message)
      log_event("ai_extraction_failed", { error: message })
      { error: message, confidence: 0.0 }
    end

    def notify_extraction_error(exception, provider_name)
      ExceptionNotifier.notify(exception, {
        context: "ai_job_extraction",
        severity: "error",
        ai_context: {
          operation: "job_extraction",
          provider_name: provider_name,
          job_listing_id: @job_listing&.id
        },
        url: @url
      })
    end

    # Prompt building

    def build_extraction_prompt(html_content)
      prompt_template = Ai::JobExtractionPrompt.active_prompt

      if prompt_template && prompt_supports_company_sections?(prompt_template.prompt_template)
        prompt_template.build_prompt(url: @url, html_content: html_content)
      else
        Ai::JobExtractionPrompt.default_prompt_template
          .gsub("{{url}}", @url)
          .gsub("{{html_content}}", html_content)
      end
    end

    def prompt_supports_company_sections?(template)
      return false unless template.is_a?(String)

      template.include?("about_company") && template.include?("company_culture")
    end

    # Response parsing

    def parse_response(response_text)
      return { error: "No response", confidence: 0.0 } unless response_text.present?

      json_match = response_text.match(/\{.*\}/m)
      return { error: "No JSON found in response", confidence: 0.0 } unless json_match

      data = JSON.parse(json_match[0])
      normalize_parsed_data(data)
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse LLM response: #{e.message}")
      { error: "Invalid JSON response", confidence: 0.0 }
    end

    def normalize_parsed_data(data)
      {
        title: data["title"],
        company: data["company"] || data["company_name"],
        job_role: data["job_role"] || data["job_role_title"],
        description: data["description"],
        about_company: data["about_company"],
        company_culture: data["company_culture"],
        requirements: data["requirements"],
        responsibilities: data["responsibilities"],
        location: data["location"],
        remote_type: data["remote_type"],
        salary_min: data["salary_min"],
        salary_max: data["salary_max"],
        salary_currency: data["salary_currency"] || "USD",
        equity_info: data["equity_info"],
        benefits: data["benefits"],
        perks: data["perks"],
        custom_sections: data["custom_sections"] || {},
        confidence: data["confidence_score"] || 0.5,
        notes: data["notes"]
      }
    end

    # Provider management

    def provider_chain
      LlmProviders::ProviderConfigHelper.all_providers
    end

    def get_provider_instance(provider_name)
      provider = case provider_name.to_s.downcase
      when "openai" then LlmProviders::OpenaiProvider.new
      when "anthropic" then LlmProviders::AnthropicProvider.new
      when "ollama" then LlmProviders::OllamaProvider.new
      else raise ArgumentError, "Unknown provider: #{provider_name}"
      end

      provider.scraping_attempt = @scraping_attempt
      provider.job_listing = @job_listing
      provider
    end
  end
end
