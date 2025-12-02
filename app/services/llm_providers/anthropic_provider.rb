# frozen_string_literal: true

module LlmProviders
  # Anthropic Claude provider for job listing extraction
  class AnthropicProvider < BaseProvider
    # Extracts structured job data using Anthropic's Claude models
    #
    # @param [String] html_content The HTML content of the job listing
    # @param [String] url The URL of the job listing
    # @return [Hash] Extracted job data with confidence scores
    def extract_job_data(html_content, url)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Build prompt and estimate tokens
      prompt = build_extraction_prompt(html_content, url)
      estimated_tokens = estimate_tokens(prompt)
      html_size = html_content.bytesize

      # Check rate limiter before making request
      rate_limiter = Scraping::AnthropicRateLimiterService.new

      unless rate_limiter.can_send_tokens?(estimated_tokens)
        wait_time = rate_limiter.wait_time_for_tokens(estimated_tokens)
        if wait_time > 0
          Rails.logger.warn("Anthropic rate limit: waiting #{wait_time}s before request (estimated: #{estimated_tokens} tokens)")
          sleep(wait_time)
        else
          # Can't send even after waiting - return rate limit error
          result = {
            error: "Request would exceed token rate limit (estimated: #{estimated_tokens} tokens)",
            confidence: 0.0,
            provider: "anthropic",
            rate_limit: true,
            error_type: "rate_limit"
          }
          log_extraction_result(result, latency_ms: 0, prompt: prompt, html_size: html_size)
          return result
        end
      end

      client = Anthropic::Client.new(api_key: api_key)

      # Use streaming for long requests (required for operations > 10 minutes)
      # Streaming is also more efficient for large content
      stream = client.messages.stream(
        model: model_name,
        max_tokens: db_config&.max_tokens || 4096,
        temperature: db_config&.temperature || 0,
        messages: [
          {
            role: "user",
            content: prompt
          }
        ]
      )

      # Collect the full text from the stream
      # accumulated_text blocks until the stream is complete and returns all text
      # It will raise an error if no text content blocks were returned
      content = stream.accumulated_text

      # Get the accumulated message for metadata (usage, etc.)
      # This also blocks until the stream is complete
      accumulated_message = stream.accumulated_message

      parsed_data = parse_response(content)

      # Record actual token usage
      input_tokens = accumulated_message&.usage&.input_tokens || estimated_tokens
      output_tokens = accumulated_message&.usage&.output_tokens
      rate_limiter.record_tokens_used(input_tokens) if input_tokens

      # Calculate latency
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      latency_ms = ((end_time - start_time) * 1000).round

      # Add provider metadata
      result = parsed_data.merge(
        provider: "anthropic",
        model: model_name,
        tokens_used: output_tokens,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        raw_response: content
      )

      # Log the extraction result
      log_extraction_result(result, latency_ms: latency_ms, prompt: prompt, html_size: html_size)

      result
    rescue => e
      # Calculate latency even for failures
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      latency_ms = ((end_time - start_time) * 1000).round rescue 0

      # Check if this is a rate limit error (429 status)
      is_rate_limit = rate_limit_error?(e)

      if is_rate_limit
        Rails.logger.warn("Anthropic rate limit exceeded: #{e.message}")

        # Extract retry-after header if available
        retry_after = extract_retry_after(e)

        # Notify exception with rate limit context
        ExceptionNotifier.notify_ai_error(e, {
          operation: "job_extraction",
          provider_name: "anthropic",
          model_identifier: model_name,
          error_type: "rate_limit_exceeded",
          url: url,
          retry_after: retry_after
        })

        # Return error with rate_limit flag so caller can retry
        result = {
          error: "Rate limit exceeded: #{e.message}",
          confidence: 0.0,
          provider: "anthropic",
          rate_limit: true,
          retry_after: retry_after,
          error_type: "rate_limit"
        }
      else
        Rails.logger.error("Anthropic extraction failed: #{e.message}")

        # Notify exception with AI context
        ExceptionNotifier.notify_ai_error(e, {
          operation: "job_extraction",
          provider_name: "anthropic",
          model_identifier: model_name,
          error_type: "extraction_failed",
          url: url
        })

        result = {
          error: e.message,
          confidence: 0.0,
          provider: "anthropic",
          error_type: e.class.name
        }
      end

      # Log the failed extraction
      log_extraction_result(result, latency_ms: latency_ms, prompt: prompt, html_size: html_size) rescue nil

      result
    end

    protected

    # Returns the Anthropic API key from credentials
    #
    # @return [String, nil] API key or nil
    def api_key
      Rails.application.credentials.dig(:anthropic, :api_key)
    end

    # Checks if an error is a rate limit error
    #
    # @param [Exception] error The error to check
    # @return [Boolean] True if rate limit error
    def rate_limit_error?(error)
      # Check error message for rate limit indicators
      error_message = error.message.to_s.downcase
      return true if error_message.include?("rate_limit") ||
                     error_message.include?("rate limit") ||
                     error_message.include?("429")

      # Check if error has status 429
      if error.respond_to?(:status) && error.status == 429
        return true
      end

      # Check response object for status 429
      if error.respond_to?(:response)
        response = error.response
        if response.is_a?(Hash)
          return true if response[:status] == 429 || response["status"] == 429

          # Check body for rate_limit_error type
          body = response[:body] || response["body"]
          if body.is_a?(Hash)
            error_info = body[:error] || body["error"]
            if error_info.is_a?(Hash)
              error_type = error_info[:type] || error_info["type"]
              return true if error_type&.downcase&.include?("rate_limit")
            end
          end
        end
      end

      false
    end

    # Extracts retry-after value from error response
    #
    # @param [Exception] error The error
    # @return [Integer, nil] Seconds to wait, or nil if not available
    def extract_retry_after(error)
      return nil unless error.respond_to?(:response)

      response = error.response
      return nil unless response

      # Try to get retry-after header
      headers = response[:headers] || response["headers"] || {}
      retry_after = headers["retry-after"] || headers[:retry_after] || headers["Retry-After"]

      return nil unless retry_after

      # Parse as integer (seconds)
      retry_after.to_i
    rescue => e
      Rails.logger.warn("Failed to extract retry-after: #{e.message}")
      nil
    end

    # Estimates token count for text
    #
    # @param [String] text The text to estimate
    # @return [Integer] Estimated token count
    def estimate_tokens(text)
      # Conservative estimate: 1 token ≈ 3 characters for HTML/text
      (text.length.to_f / 3.0).ceil
    end
  end
end
