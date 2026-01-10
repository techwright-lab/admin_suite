# frozen_string_literal: true

module Scraping
  # LLM-based post-processor for job content.
  #
  # Used after a high-confidence source (e.g., Greenhouse boards API) fetch to:
  # - Extract missing structured fields (compensation, interview process, etc.)
  # - Produce a clean Markdown version for display
  #
  # This is deliberately "best effort" and should not fail the scrape.
  class AiJobPostProcessorService
    attr_reader :job_listing, :scraping_attempt

    # @param job_listing [JobListing]
    # @param scraping_attempt [ScrapingAttempt, nil]
    # @param providers [Array<String>, nil] Optional provider chain override
    def initialize(job_listing, scraping_attempt: nil, providers: nil)
      @job_listing = job_listing
      @scraping_attempt = scraping_attempt
      @providers = providers
    end

    # @param content_html [String]
    # @param url [String]
    # @return [Hash] normalized result hash (best effort)
    def run(content_html:, url:)
      return { error: "No content", confidence: 0.0 } if content_html.blank?

      prompt_template = Ai::JobPostprocessPrompt.active_prompt
      prompt = if prompt_template
        prompt_template.build_prompt(url: url, html_content: content_html)
      else
        Ai::JobPostprocessPrompt.default_prompt_template
          .gsub("{{url}}", url)
          .gsub("{{html_content}}", content_html)
      end

      provider_chain.each do |provider_name|
        provider = get_provider_instance(provider_name)
        next unless provider.available?

        system_message = prompt_template&.system_prompt.presence || Ai::JobPostprocessPrompt.default_system_prompt
        result = provider.run(prompt, system_message: system_message)
        parsed = parse_json_result(result[:content])
        confidence = parsed[:confidence].to_f

        Ai::ApiLoggerService.new(
          operation_type: :job_postprocess,
          loggable: job_listing,
          provider: result[:provider],
          model: result[:model],
          llm_prompt: prompt_template
        ).record(prompt: prompt, content_size: content_html.bytesize) do
          parsed.merge(
            content: result[:content],
            input_tokens: result[:input_tokens],
            output_tokens: result[:output_tokens],
            confidence: confidence,
            provider_request: result[:provider_request],
            provider_response: result[:provider_response],
            provider_error_response: result[:provider_error_response],
            http_status: result[:http_status],
            response_headers: result[:response_headers],
            provider_endpoint: result[:provider_endpoint],
            error: result[:error],
            error_type: result[:error_type]
          )
        end

        return parsed if confidence > 0.0
      end

      { error: "No provider available", confidence: 0.0 }
    rescue => e
      ExceptionNotifier.notify(e, {
        context: "ai_job_postprocess",
        severity: "warning",
        job_listing_id: job_listing.id,
        scraping_attempt_id: scraping_attempt&.id,
        url: url
      })
      { error: e.message, confidence: 0.0 }
    end

    private

    def parse_json_result(text)
      return { error: "No response", confidence: 0.0 } if text.blank?
      json_match = text.match(/\{.*\}/m)
      return { error: "No JSON found", confidence: 0.0 } unless json_match

      data = JSON.parse(json_match[0])
      normalize_parsed_data(data)
    rescue JSON::ParserError => e
      { error: "Invalid JSON: #{e.message}", confidence: 0.0 }
    end

    def normalize_parsed_data(data)
      {
        job_markdown: data["job_markdown"].to_s,
        compensation_text: data["compensation_text"],
        salary_min: data["salary_min"],
        salary_max: data["salary_max"],
        salary_currency: data["salary_currency"],
        interview_process: data["interview_process"],
        responsibilities_bullets: Array(data["responsibilities_bullets"]).map(&:to_s),
        requirements_bullets: Array(data["requirements_bullets"]).map(&:to_s),
        benefits_bullets: Array(data["benefits_bullets"]).map(&:to_s),
        perks_bullets: Array(data["perks_bullets"]).map(&:to_s),
        confidence: data["confidence_score"].to_f
      }
    end

    def provider_chain
      @providers.presence || LlmProviders::ProviderConfigHelper.all_providers
    end

    def get_provider_instance(provider_name)
      provider = case provider_name.to_s.downcase
      when "openai" then LlmProviders::OpenaiProvider.new
      when "anthropic" then LlmProviders::AnthropicProvider.new
      when "ollama" then LlmProviders::OllamaProvider.new
      else raise ArgumentError, "Unknown provider: #{provider_name}"
      end

      provider.scraping_attempt = scraping_attempt
      provider.job_listing = job_listing
      provider
    end
  end
end
