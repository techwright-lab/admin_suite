# frozen_string_literal: true

module LlmProviders
  # OpenAI provider for job listing extraction using Responses API
  #
  # Uses the Responses API for structured outputs with better reliability
  # Reference: https://platform.openai.com/docs/api-reference/responses
  # Reference: https://github.com/openai/openai-ruby
  class OpenaiProvider < BaseProvider
    # JSON schema for job listing extraction
    EXTRACTION_SCHEMA = {
      type: "object",
      properties: {
        title: { type: [ "string", "null" ] },
        company: { type: [ "string", "null" ] },
        job_role: { type: [ "string", "null" ] },
        description: { type: [ "string", "null" ] },
        requirements: { type: [ "string", "null" ] },
        responsibilities: { type: [ "string", "null" ] },
        location: { type: [ "string", "null" ] },
        remote_type: {
          type: "string",
          enum: [ "on_site", "hybrid", "remote" ]
        },
        salary_min: { type: [ "number", "null" ] },
        salary_max: { type: [ "number", "null" ] },
        salary_currency: { type: "string", default: "USD" },
        equity_info: { type: [ "string", "null" ] },
        benefits: { type: [ "string", "null" ] },
        perks: { type: [ "string", "null" ] },
        custom_sections: { type: "object", additionalProperties: true },
        confidence_score: { type: "number", minimum: 0, maximum: 1 },
        notes: { type: [ "string", "null" ] }
      },
      required: [ "title", "confidence_score" ],
      additionalProperties: false
    }.freeze

    # Extracts structured job data using OpenAI's Responses API
    #
    # Uses the Responses API endpoint which provides better structured outputs
    # Reference: https://platform.openai.com/docs/api-reference/responses
    #
    # @param [String] html_content The HTML content of the job listing
    # @param [String] url The URL of the job listing
    # @return [Hash] Extracted job data with confidence scores
    def extract_job_data(html_content, url)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      prompt = build_extraction_prompt(html_content, url)
      html_size = html_content.bytesize

      client = OpenAI::Client.new(access_token: api_key)

      # Use Responses API for structured outputs
      # The Responses API provides guaranteed JSON schema compliance
      # Reference: https://platform.openai.com/docs/api-reference/responses
      response = client.responses.create(
        parameters: {
          model: model_name,
          messages: [
            {
              role: "system",
              content: "You are an expert at extracting structured data from job listings. Always return valid JSON matching the schema."
            },
            {
              role: "user",
              content: prompt
            }
          ],
          response_format: {
            type: "json_schema",
            json_schema: {
              name: "job_listing_extraction",
              strict: true,
              schema: EXTRACTION_SCHEMA
            }
          },
          temperature: db_config&.temperature || 0,
          max_completion_tokens: db_config&.max_tokens || 16384
        }
      )

      # Responses API returns structured data directly
      # The response structure may be different from chat completions
      # Check if response is a hash (from JSON) or an object
      response_data = response.is_a?(Hash) ? response : response.to_h

      # Extract content from response - structure may vary
      content = response_data.dig("output", 0, "content") ||
                response_data.dig("choices", 0, "message", "content") ||
                response_data.dig("content")

      # With Responses API, the response is guaranteed to match our schema
      parsed_data = content.is_a?(String) ? JSON.parse(content) : content

      # Calculate latency
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      latency_ms = ((end_time - start_time) * 1000).round

      # Extract token usage
      input_tokens = response_data.dig("usage", "prompt_tokens")
      output_tokens = response_data.dig("usage", "completion_tokens")
      total_tokens = response_data.dig("usage", "total_tokens")

      # Add provider metadata
      result = {
        title: parsed_data["title"],
        company: parsed_data["company"],
        job_role: parsed_data["job_role"],
        description: parsed_data["description"],
        requirements: parsed_data["requirements"],
        responsibilities: parsed_data["responsibilities"],
        location: parsed_data["location"],
        remote_type: parsed_data["remote_type"],
        salary_min: parsed_data["salary_min"],
        salary_max: parsed_data["salary_max"],
        salary_currency: parsed_data["salary_currency"] || "USD",
        equity_info: parsed_data["equity_info"],
        benefits: parsed_data["benefits"],
        perks: parsed_data["perks"],
        custom_sections: parsed_data["custom_sections"] || {},
        confidence: parsed_data["confidence_score"] || 0.5,
        notes: parsed_data["notes"],
        provider: "openai",
        model: model_name,
        tokens_used: total_tokens || output_tokens,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        raw_response: content.is_a?(String) ? content : content.to_json
      }

      # Log the extraction result
      log_extraction_result(result, latency_ms: latency_ms, prompt: prompt, html_size: html_size)

      result
    rescue JSON::ParserError => e
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      latency_ms = ((end_time - start_time) * 1000).round rescue 0

      Rails.logger.error("OpenAI JSON parsing failed: #{e.message}")

      # Notify exception with AI context
      ExceptionNotifier.notify_ai_error(e, {
        operation: "job_extraction",
        provider_name: "openai",
        model_identifier: model_name,
        error_type: "json_parsing",
        url: url
      })

      result = {
        error: "Invalid JSON response: #{e.message}",
        confidence: 0.0,
        provider: "openai",
        error_type: "json_parsing"
      }

      log_extraction_result(result, latency_ms: latency_ms, prompt: prompt, html_size: html_size) rescue nil

      result
    rescue => e
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      latency_ms = ((end_time - start_time) * 1000).round rescue 0

      Rails.logger.error("OpenAI extraction failed: #{e.message}")

      # Extract HTTP status if available
      http_status = if e.respond_to?(:response)
        response = e.response
        if response.is_a?(Hash)
          response[:status] || response["status"] || response[:code] || response["code"]
        elsif response.respond_to?(:code)
          response.code
        elsif response.respond_to?(:status)
          response.status
        end
      end

      # Notify exception with AI context
      ExceptionNotifier.notify_ai_error(e, {
        operation: "job_extraction",
        provider_name: "openai",
        model_identifier: model_name,
        error_type: "extraction_failed",
        url: url,
        http_status: http_status
      })

      result = {
        error: e.message,
        confidence: 0.0,
        provider: "openai",
        error_type: e.class.name
      }

      log_extraction_result(result, latency_ms: latency_ms, prompt: prompt, html_size: html_size) rescue nil

      result
    end

    protected

    # Returns the OpenAI API key from credentials
    #
    # @return [String, nil] API key or nil
    def api_key
      Rails.application.credentials.dig(:openai, :api_key)
    end
  end
end
