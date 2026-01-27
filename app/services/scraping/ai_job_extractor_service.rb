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
  class AiJobExtractorService < ApplicationService
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
      prompt_template = Ai::JobExtractionPrompt.active_prompt
      system_message = prompt_template&.system_prompt.presence || Ai::JobExtractionPrompt.default_system_prompt

      runner = Ai::ProviderRunnerService.new(
        provider_chain: provider_chain,
        prompt: prompt,
        content_size: html_size,
        system_message: system_message,
        provider_for: method(:get_provider_instance),
        logger_builder: lambda { |provider_name, provider|
          Ai::ApiLoggerService.new(
            operation_type: :job_extraction,
            loggable: @job_listing,
            provider: provider_name,
            model: provider.respond_to?(:model_name) ? provider.model_name : "unknown",
            llm_prompt: prompt_template
          )
        },
        on_rate_limit: lambda { |response, provider_name, _logger|
          handle_rate_limit(provider_name, response)
        },
        on_error: lambda { |response, provider_name, _logger|
          log_event("ai_extraction_failed", { provider: provider_name, error: response[:error] })
        },
        operation: :job_extraction,
        loggable: @job_listing,
        user: job_listing_user,
        error_context: {
          severity: "warning",
          job_listing_id: @job_listing&.id,
          url: @url
        }
      )

      result = runner.run do |response|
        parsed = parse_response(response[:content])
        log_data = (parsed || {}).merge(
          confidence: parsed&.dig(:confidence),
          model: response[:model]
        )
        [ parsed, log_data, true ]
      end

      return extraction_error("All providers failed or returned low confidence") unless result[:success]

      confidence = result[:parsed][:confidence] || 0.0
      if confidence >= 0.7
        log_event("ai_extraction_succeeded", { provider: result[:provider], confidence: confidence })
      else
        log_event("ai_extraction_low_confidence", { provider: result[:provider], confidence: confidence })
      end

      build_extraction_result(result[:parsed], result[:result].merge(model: result[:model]), result[:provider]).merge(
        prompt_used: prompt
      )
    end

    def job_listing_user
      @job_listing.interview_applications.order(created_at: :desc).first&.user
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
        raw_response: result[:content] || result[:raw_response]
      )
    end

    def extraction_error(message)
      log_event("ai_extraction_failed", { error: message })
      { error: message, confidence: 0.0 }
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
      # Build custom_sections with markdown and additional extracted fields
      custom_sections = data["custom_sections"] || {}
      custom_sections["description_markdown"] = data["description_markdown"] if data["description_markdown"].present?
      custom_sections["compensation_text"] = data["compensation_text"] if data["compensation_text"].present?
      custom_sections["interview_process"] = data["interview_process"] if data["interview_process"].present?

      {
        title: data["title"],
        company: data["company"] || data["company_name"],
        job_role: data["job_role"] || data["job_role_title"],
        job_role_department: data["job_role_department"],
        job_board: data["job_board"],
        description: data["description"],
        description_markdown: data["description_markdown"],
        about_company: data["about_company"],
        company_culture: data["company_culture"],
        requirements: data["requirements"],
        responsibilities: data["responsibilities"],
        location: data["location"],
        remote_type: data["remote_type"],
        salary_min: data["salary_min"],
        salary_max: data["salary_max"],
        salary_currency: data["salary_currency"] || "USD",
        compensation_text: data["compensation_text"],
        equity_info: data["equity_info"],
        benefits: data["benefits"],
        perks: data["perks"],
        interview_process: data["interview_process"],
        custom_sections: custom_sections,
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
