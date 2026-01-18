# frozen_string_literal: true

module ApiFetchers
  # Base fetcher class for job board API integrations
  #
  # Provides common functionality for making API requests
  # and parsing responses.
  #
  # @abstract Subclass and override {#fetch} to implement
  class BaseFetcher < ApplicationService
    # Logs a structured event for API operations
    #
    # @param [String] event_name The event name
    # @param [Hash] data Additional event data
    def log_event(event_name, data = {})
      base_data = {
        event: event_name,
        service: self.class.name
      }
      Rails.logger.info(base_data.merge(data).to_json)
    end

    # Logs an error for API operations
    #
    # @param [String] message The error message
    # @param [Exception, nil] exception Optional exception object
    def log_error(message, exception = nil)
      error_data = {
        error: message,
        service: self.class.name
      }

      if exception
        error_data.merge!(
          exception: exception.class.name,
          message: exception.message,
          backtrace: exception.backtrace&.first(5)
        )
      end

      Rails.logger.error(error_data.to_json)
    end
    # Fetches job listing data from the API
    #
    # @param [String] url The job listing URL
    # @param [String] job_id The job ID
    # @param [String] company_slug The company identifier
    # @return [Hash] Standardized job data
    # @raise [NotImplementedError] Must be implemented by subclass
    def fetch(url:, job_id: nil, company_slug: nil)
      raise NotImplementedError, "#{self.class} must implement #fetch"
    end

    protected

    # Makes an API request with standard headers and error handling
    #
    # @param [String] url The API endpoint URL
    # @param [Hash] headers Additional headers
    # @return [HTTParty::Response] The response
    def make_request(url, headers: {})
      HTTParty.get(
        url,
        headers: default_headers.merge(headers),
        timeout: 30,
        open_timeout: 10,
        follow_redirects: true
      )
    rescue => e
      log_error("API request failed", e)
      raise
    end

    # Returns default headers for API requests
    #
    # @return [Hash] Default headers
    def default_headers
      {
        "User-Agent" => "GleaniaBot/1.0 (+https://gleania.com/bot)",
        "Accept" => "application/json"
      }
    end

    # Normalizes the API response to our standard format
    #
    # @param [Hash] api_data The raw API response
    # @return [Hash] Standardized job data
    def normalize_response(api_data)
      {
        title: api_data[:title],
        description: api_data[:description],
        requirements: api_data[:requirements],
        responsibilities: api_data[:responsibilities],
        location: api_data[:location],
        remote_type: api_data[:remote_type] || "on_site",
        salary_min: api_data[:salary_min],
        salary_max: api_data[:salary_max],
        salary_currency: api_data[:salary_currency] || "USD",
        equity_info: api_data[:equity_info],
        benefits: api_data[:benefits],
        perks: api_data[:perks],
        custom_sections: api_data[:custom_sections] || {},
        confidence: 1.0, # API data is high confidence
        extraction_method: "api",
        provider: provider_name
      }
    end

    # Returns the provider name
    #
    # @return [String] Provider name
    def provider_name
      self.class.name.demodulize.gsub("Fetcher", "").downcase
    end
  end
end
