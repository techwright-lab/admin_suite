# frozen_string_literal: true

module LlmProviders
  # Anthropic Claude provider for LLM completions
  #
  # Uses the Anthropic Ruby SDK with streaming for efficient long-running requests.
  # Includes rate limiting via AnthropicRateLimiterService.
  class AnthropicProvider < BaseProvider
    # Sends a prompt to Claude and returns the response
    #
    # @param prompt [String] The prompt text
    # @param options [Hash] Optional parameters
    #   @option options [Integer] :max_tokens Maximum tokens in response
    #   @option options [Float] :temperature Temperature setting
    #   @option options [String] :system_message Optional system message
    # @return [Hash] Result with content and metadata
    def run(prompt, options = {})
      return rate_limit_error_response if exceeds_rate_limit?(prompt)

      result, latency_ms = with_timing { call_api(prompt, options) }
      build_response(result, latency_ms)
    rescue => e
      handle_error(e)
    end

    protected

    def api_key
      Rails.application.credentials.dig(:anthropic, :api_key)
    end

    def default_model
      "claude-sonnet-4-20250514"
    end

    private

    # Checks rate limit and waits or returns error
    def exceeds_rate_limit?(prompt)
      estimated_tokens = estimate_tokens(prompt)

      unless rate_limiter.can_send_tokens?(estimated_tokens)
        wait_time = rate_limiter.wait_time_for_tokens(estimated_tokens)
        if wait_time > 0
          Rails.logger.warn("Anthropic rate limit: waiting #{wait_time}s")
          sleep(wait_time)
          return false
        end
        @rate_limit_tokens = estimated_tokens
        return true
      end
      false
    end

    def rate_limit_error_response
      error_response(
        error: "Request would exceed token rate limit",
        latency_ms: 0,
        error_type: "rate_limit",
        rate_limit: true
      )
    end

    # Makes the actual API call
    def call_api(prompt, options)
      client = Anthropic::Client.new(api_key: api_key)

      params = build_params(prompt, options)
      stream = client.messages.stream(**params)

      content = stream.accumulated_text
      message = stream.accumulated_message

      record_token_usage(message)

      {
        content: content,
        input_tokens: message&.usage&.input_tokens,
        output_tokens: message&.usage&.output_tokens
      }
    end

    def build_params(prompt, options)
      params = {
        model: model_name,
        max_tokens: options[:max_tokens] || max_tokens_config,
        temperature: options[:temperature] || temperature_config,
        messages: [ { role: "user", content: prompt } ]
      }

      params[:system] = options[:system_message] if options[:system_message].present?
      params
    end

    def build_response(result, latency_ms)
      success_response(
        content: result[:content],
        latency_ms: latency_ms,
        input_tokens: result[:input_tokens],
        output_tokens: result[:output_tokens]
      )
    end

    def handle_error(exception)
      latency_ms = 0 # Error occurred, timing not meaningful

      if rate_limit_error?(exception)
        handle_rate_limit_error(exception, latency_ms)
      else
        handle_general_error(exception, latency_ms)
      end
    end

    def handle_rate_limit_error(exception, latency_ms)
      Rails.logger.warn("Anthropic rate limit exceeded: #{exception.message}")
      retry_after = extract_retry_after(exception)

      notify_error(exception, operation: "run", error_type: "rate_limit_exceeded", retry_after: retry_after)

      error_response(
        error: "Rate limit exceeded: #{exception.message}",
        latency_ms: latency_ms,
        error_type: "rate_limit",
        rate_limit: true,
        retry_after: retry_after
      )
    end

    def handle_general_error(exception, latency_ms)
      Rails.logger.error("Anthropic request failed: #{exception.message}")

      notify_error(exception, operation: "run", error_type: "request_failed")

      error_response(
        error: exception.message,
        latency_ms: latency_ms,
        error_type: exception.class.name
      )
    end

    # Rate limiting helpers

    def rate_limiter
      @rate_limiter ||= Scraping::AnthropicRateLimiterService.new
    end

    def record_token_usage(message)
      input_tokens = message&.usage&.input_tokens
      rate_limiter.record_tokens_used(input_tokens) if input_tokens
    end

    def estimate_tokens(text)
      (text.length.to_f / 3.0).ceil
    end

    def rate_limit_error?(error)
      message = error.message.to_s.downcase
      return true if message.include?("rate_limit") || message.include?("rate limit") || message.include?("429")
      return true if error.respond_to?(:status) && error.status == 429
      check_response_for_rate_limit(error)
    end

    def check_response_for_rate_limit(error)
      return false unless error.respond_to?(:response)

      response = error.response
      return false unless response.is_a?(Hash)
      return true if response[:status] == 429 || response["status"] == 429

      error_type = response.dig(:body, :error, :type) || response.dig("body", "error", "type")
      error_type&.downcase&.include?("rate_limit") || false
    end

    def extract_retry_after(error)
      return nil unless error.respond_to?(:response)

      headers = error.response&.dig(:headers) || error.response&.dig("headers") || {}
      retry_after = headers["retry-after"] || headers[:retry_after] || headers["Retry-After"]
      retry_after&.to_i
    rescue
      nil
    end
  end
end
