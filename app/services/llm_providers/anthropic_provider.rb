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
      return rate_limit_error_response if prompt.present? && exceeds_rate_limit?(prompt)

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
      estimated_tokens = estimate_tokens(prompt.to_s)

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
      @last_provider_request = build_params(prompt, options)
      @last_provider_endpoint =
        if Setting.helicone_enabled?
          Rails.application.credentials.dig(:helicone, :base_url)
        else
          nil
        end

      if  Setting.helicone_enabled?
        client = Anthropic::Client.new(
          api_key: Rails.application.credentials.dig(:helicone, :api_key),
          base_url: Rails.application.credentials.dig(:helicone, :base_url)
        )
      else
        client = Anthropic::Client.new(api_key: api_key)
      end
      stream = client.messages.stream(**@last_provider_request)

      message = stream.accumulated_message
      message_hash = message.respond_to?(:to_h) ? message.to_h : message
      parsed = parse_message(message)
      # Use SDK-provided text accumulator as the most reliable source of assistant text.
      content = stream.accumulated_text.to_s
      content = parsed[:content] if content.blank?

      record_token_usage(message)

      parsed = {
        content: content,
        tool_calls: parsed[:tool_calls],
        content_blocks: parsed[:content_blocks],
        message_id: message&.id,
        provider_request: @last_provider_request,
        provider_response: message_hash.is_a?(Hash) ? message_hash : message_hash.to_s,
        provider_endpoint: @last_provider_endpoint,
        input_tokens: message&.usage&.input_tokens,
        output_tokens: message&.usage&.output_tokens
      }

      contract = Assistant::Contracts::ProviderResultContracts::Anthropic.call(parsed)
      unless contract.success?
        notify_error(RuntimeError.new("Anthropic provider contract failed"), operation: "call_api", error_type: "contract_failed", contract_errors: contract.errors.to_h)
      end

      parsed
    end

    def build_params(prompt, options)
      params = {
        model: model_name,
        max_tokens: options[:max_tokens] || max_tokens_config,
        temperature: options[:temperature] || temperature_config,
        messages: build_messages(prompt, options)
      }

      params[:system] = options[:system_message] if options[:system_message].present?
      params[:tools] = options[:tools] if options[:tools].present?
      params[:tool_choice] = options[:tool_choice] if options.key?(:tool_choice)
      params
    end

    def build_messages(prompt, options)
      return Array(options[:messages]) if options[:messages].present?
      [ { role: "user", content: prompt } ]
    end

    def parse_message(message)
      message_hash = message.respond_to?(:to_h) ? message.to_h : message
      blocks = message_hash.is_a?(Hash) ? (message_hash["content"] || message_hash[:content]) : message&.content
      return { content: "", tool_calls: [] } unless blocks.is_a?(Array)

      text_parts = []
      tool_calls = []
      content_blocks = []

      blocks.each do |b|
        h =
          if b.is_a?(Hash)
            b
          elsif b.respond_to?(:to_h)
            b.to_h
          else
            # Best-effort for SDK objects
            {
              type: (b.respond_to?(:type) ? b.type : nil),
              text: (b.respond_to?(:text) ? b.text : nil),
              id: (b.respond_to?(:id) ? b.id : nil),
              name: (b.respond_to?(:name) ? b.name : nil),
              input: (b.respond_to?(:input) ? b.input : nil)
            }.compact
          end
        next unless h.is_a?(Hash)
        content_blocks << h

        type = (h["type"] || h[:type]).to_s
        case type
        when "text"
          text_parts << (h["text"] || h[:text]).to_s
        when "output_text"
          text_parts << (h["text"] || h[:text]).to_s
        when "tool_use"
          raw_input = h["input"] || h[:input] || {}
          parsed_input =
            if raw_input.is_a?(String)
              JSON.parse(raw_input)
            else
              raw_input
            end

          tool_calls << {
            id: h["id"] || h[:id],
            tool_key: h["name"] || h[:name],
            args: parsed_input.is_a?(Hash) ? parsed_input : {}
          }
        else
          # Best-effort: if this block contains a text payload, capture it.
          text = h["text"] || h[:text]
          text_parts << text.to_s if text.is_a?(String) && text.present?
        end
      end

      { content: text_parts.join, tool_calls: tool_calls, content_blocks: content_blocks }
    end

    def build_response(result, latency_ms)
      success_response(
        content: result[:content],
        latency_ms: latency_ms,
        input_tokens: result[:input_tokens],
        output_tokens: result[:output_tokens],
        provider_request: result[:provider_request],
        provider_response: result[:provider_response],
        provider_endpoint: result[:provider_endpoint]
      ).merge(
        tool_calls: result[:tool_calls],
        content_blocks: result[:content_blocks],
        message_id: result[:message_id]
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
      http_status = extract_http_status(exception)
      error_response_hash = extract_error_response_hash(exception)

      notify_error(exception, operation: "run", error_type: "rate_limit_exceeded", retry_after: retry_after, http_status: http_status)

      error_response(
        error: "Rate limit exceeded: #{exception.message}",
        latency_ms: latency_ms,
        error_type: "rate_limit",
        rate_limit: true,
        retry_after: retry_after,
        provider_request: @last_provider_request,
        provider_error_response: error_response_hash,
        http_status: http_status,
        response_headers: error_response_hash&.dig(:headers),
        provider_endpoint: @last_provider_endpoint
      )
    end

    def handle_general_error(exception, latency_ms)
      Rails.logger.error("Anthropic request failed: #{exception.message}")

      http_status = extract_http_status(exception)
      error_response_hash = extract_error_response_hash(exception)
      notify_error(exception, operation: "run", error_type: "request_failed", http_status: http_status)

      error_response(
        error: exception.message,
        latency_ms: latency_ms,
        error_type: exception.class.name,
        provider_request: @last_provider_request,
        provider_error_response: error_response_hash,
        http_status: http_status,
        response_headers: error_response_hash&.dig(:headers),
        provider_endpoint: @last_provider_endpoint
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

    def extract_http_status(exception)
      return nil unless exception.respond_to?(:response)

      response = exception.response
      return response[:status] || response["status"] if response.is_a?(Hash)

      nil
    rescue StandardError
      nil
    end

    def extract_response_body(exception)
      return nil unless exception.respond_to?(:response)

      response = exception.response
      return response[:body] || response["body"] if response.is_a?(Hash)

      nil
    rescue StandardError
      nil
    end

    def extract_response_headers(exception)
      return nil unless exception.respond_to?(:response)

      response = exception.response
      return response[:headers] || response["headers"] if response.is_a?(Hash)

      nil
    rescue StandardError
      nil
    end

    def extract_error_response_hash(exception)
      http_status = extract_http_status(exception)
      body = extract_response_body(exception)
      headers = extract_response_headers(exception)
      return nil if http_status.blank? && body.blank? && headers.blank?

      {
        status: http_status,
        headers: headers,
        body: body
      }.compact
    end
  end
end
