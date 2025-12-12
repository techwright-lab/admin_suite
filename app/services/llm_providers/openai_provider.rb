# frozen_string_literal: true

module LlmProviders
  # OpenAI provider for LLM completions
  #
  # Uses the OpenAI Responses API for better reliability and structured outputs.
  # Reference: https://platform.openai.com/docs/api-reference/responses
  class OpenaiProvider < BaseProvider
    # Sends a prompt to OpenAI and returns the response
    #
    # @param prompt [String] The prompt text
    # @param options [Hash] Optional parameters
    #   @option options [Integer] :max_tokens Maximum tokens in response
    #   @option options [Float] :temperature Temperature setting
    #   @option options [String] :system_message Optional system message
    # @return [Hash] Result with content and metadata
    def run(prompt, options = {})
      result, latency_ms = with_timing { call_api(prompt, options) }
      build_response(result, latency_ms)
    rescue JSON::ParserError => e
      handle_json_error(e)
    rescue => e
      handle_error(e)
    end

    protected

    def api_key
      Rails.application.credentials.dig(:openai, :api_key)
    end

    def default_model
      "gpt-4o-mini"
    end

    private

    def call_api(prompt, options)
      client = OpenAI::Client.new(access_token: api_key)

      response = client.responses.create(parameters: build_params(prompt, options))
      parse_response(response)
    end

    def build_params(prompt, options)
      messages = build_messages(prompt, options[:system_message])

      {
        model: model_name,
        input: messages,
        temperature: options[:temperature] || temperature_config,
        max_output_tokens: options[:max_tokens] || max_tokens_config(default: 16384)
      }
    end

    def build_messages(prompt, system_message)
      messages = []
      messages << { role: "system", content: system_message } if system_message.present?
      messages << { role: "user", content: prompt }
      messages
    end

    def parse_response(response)
      response_data = response.is_a?(Hash) ? response : response.to_h

      content = extract_content(response_data)
      usage = response_data["usage"] || {}

      {
        content: content,
        input_tokens: usage["input_tokens"],
        output_tokens: usage["output_tokens"]
      }
    end

    def extract_content(response_data)
      # Responses API structure: output -> [{ type: "message", content: [{ type: "output_text", text: "..." }] }]
      output = response_data["output"]
      return "" unless output.is_a?(Array)

      message = output.find { |o| o["type"] == "message" }
      return "" unless message

      content_blocks = message["content"]
      return "" unless content_blocks.is_a?(Array)

      text_block = content_blocks.find { |c| c["type"] == "output_text" }
      text_block&.dig("text") || ""
    end

    def build_response(result, latency_ms)
      success_response(
        content: result[:content],
        latency_ms: latency_ms,
        input_tokens: result[:input_tokens],
        output_tokens: result[:output_tokens]
      )
    end

    def handle_json_error(exception)
      Rails.logger.error("OpenAI JSON parsing failed: #{exception.message}")

      notify_error(exception, operation: "run", error_type: "json_parsing")

      error_response(
        error: "Invalid JSON response: #{exception.message}",
        latency_ms: 0,
        error_type: "json_parsing"
      )
    end

    def handle_error(exception)
      Rails.logger.error("OpenAI request failed: #{exception.message}")

      http_status = extract_http_status(exception)
      notify_error(exception, operation: "run", error_type: "request_failed", http_status: http_status)

      error_response(
        error: exception.message,
        latency_ms: 0,
        error_type: exception.class.name
      )
    end

    def extract_http_status(exception)
      return nil unless exception.respond_to?(:response)

      response = exception.response
      if response.is_a?(Hash)
        response[:status] || response["status"] || response[:code] || response["code"]
      elsif response.respond_to?(:code)
        response.code
      elsif response.respond_to?(:status)
        response.status
      end
    end
  end
end
