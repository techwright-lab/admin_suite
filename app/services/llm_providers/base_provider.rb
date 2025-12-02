# frozen_string_literal: true

module LlmProviders
  # Base provider class for LLM integrations
  #
  # All LLM providers must implement this interface to be used for
  # job listing data extraction.
  #
  # @abstract Subclass and override {#extract_job_data} to implement
  class BaseProvider
    # Logging context attributes (set by AiJobExtractorService)
    attr_accessor :scraping_attempt, :job_listing

    # Extracts structured job data from HTML content
    #
    # @param [String] html_content The HTML content of the job listing
    # @param [String] url The URL of the job listing
    # @return [Hash] Extracted job data with confidence scores
    # @raise [NotImplementedError] Must be implemented by subclass
    def extract_job_data(html_content, url)
      raise NotImplementedError, "#{self.class} must implement #extract_job_data"
    end

    # Checks if the provider is available and configured
    #
    # @return [Boolean] True if provider can be used
    def available?
      api_key.present? && enabled?
    end

    # Returns the provider name
    #
    # @return [String] Provider name
    def provider_name
      self.class.name.demodulize.gsub("Provider", "").downcase
    end

    # Returns the model name being used
    #
    # @return [String] Model name
    def model_name
      config["model"]
    end

    protected

    # Returns the API key for this provider
    #
    # @return [String, nil] API key or nil if not configured
    # @raise [NotImplementedError] Must be implemented by subclass
    def api_key
      raise NotImplementedError, "#{self.class} must implement #api_key"
    end

    # Returns the database configuration for this provider
    #
    # @return [LlmProviderConfig, nil] Provider configuration or nil
    def db_config
      @db_config ||= ::LlmProviderConfig.by_provider_type(provider_name).enabled.first
    end

    # Returns the configuration for this provider
    #
    # @return [Hash] Provider configuration
    def config
      @config ||= db_config&.to_config || {}
    end

    # Checks if provider is enabled in configuration
    #
    # @return [Boolean] True if enabled
    def enabled?
      db_config&.enabled? || false
    end

    # Returns the model name from database config
    #
    # @return [String] Model name
    def model_name
      db_config&.llm_model || config["model"] || "unknown"
    end

    # Builds the extraction prompt for the LLM
    #
    # @param [String] html_content The HTML content to extract from
    # @param [String] url The job listing URL
    # @return [String] The formatted prompt
    def build_extraction_prompt(html_content, url)
      # Use active prompt template from database
      template = ExtractionPromptTemplate.active_prompt

      if template
        template.build_prompt(
          url: url,
          html_content: html_content
        )
      else
        # Fallback to default prompt
        ExtractionPromptTemplate.default_prompt
          .gsub("{{url}}", url)
          .gsub("{{html_content}}", html_content)
      end
    end

    # Creates an extraction logger for observability
    #
    # @param [String, nil] prompt The prompt text
    # @param [Integer, nil] html_size Size of HTML content
    # @return [AiExtractionLoggerService] The logger instance
    def create_extraction_logger(prompt: nil, html_size: nil)
      AiExtractionLoggerService.new(
        scraping_attempt: scraping_attempt,
        job_listing: job_listing,
        provider: provider_name,
        model: model_name,
        prompt_template_id: ExtractionPromptTemplate.active_prompt&.id
      )
    end

    # Records an extraction result to the log
    #
    # @param [Hash] result The extraction result
    # @param [Integer] latency_ms Latency in milliseconds
    # @param [String, nil] prompt The prompt text
    # @param [Integer, nil] html_size Size of HTML content
    # @return [AiExtractionLog, nil] The log record or nil
    def log_extraction_result(result, latency_ms:, prompt: nil, html_size: nil)
      logger = create_extraction_logger(prompt: prompt, html_size: html_size)
      logger.record_result(result, latency_ms: latency_ms, prompt: prompt, html_size: html_size)
    rescue => e
      Rails.logger.warn("Failed to log extraction result: #{e.message}")
      nil
    end

    # Parses and validates the LLM response
    #
    # @param [String] response_text The LLM response text
    # @return [Hash] Parsed and validated response
    def parse_response(response_text)
      # Try to extract JSON from the response
      json_match = response_text.match(/\{.*\}/m)
      return { error: "No JSON found in response", confidence: 0.0 } unless json_match

      data = JSON.parse(json_match[0])

      # Ensure required fields have defaults
      {
        title: data["title"],
        company: data["company"],
        job_role: data["job_role"],
        description: data["description"],
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
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse LLM response: #{e.message}")
      { error: "Invalid JSON response", confidence: 0.0 }
    end
  end

  # Configuration helper for LLM providers (database-backed)
  module ProviderConfigHelper
    class << self
      # Returns the default provider name
      #
      # @return [String] Default provider name
      def default_provider
        ::LlmProviderConfig.default_provider&.provider_type || "anthropic"
      end

      # Returns the list of fallback provider names
      #
      # @return [Array<String>] Fallback provider names
      def fallback_providers
        ::LlmProviderConfig.fallback_providers.pluck(:provider_type)
      end

      # Returns all available providers in priority order
      #
      # @return [Array<String>] Provider names
      def all_providers
        [ default_provider ] + fallback_providers
      end
    end
  end
end
