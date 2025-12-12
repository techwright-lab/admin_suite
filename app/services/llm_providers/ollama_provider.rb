# frozen_string_literal: true

module LlmProviders
  # Ollama provider for self-hosted LLM completions
  #
  # Uses the Ollama REST API for local model inference.
  # Does not require an API key - connects to local Ollama server.
  class OllamaProvider < BaseProvider
    REQUEST_TIMEOUT = 120 # Longer timeout for local inference

    # Sends a prompt to Ollama and returns the response
    #
    # @param prompt [String] The prompt text
    # @param options [Hash] Optional parameters (temperature not supported by Ollama)
    # @return [Hash] Result with content and metadata
    def run(prompt, options = {})
      result, latency_ms = with_timing { call_api(prompt, options) }
      build_response(result, latency_ms)
    rescue => e
      handle_error(e)
    end

    # Ollama doesn't require an API key
    def available?
      enabled? && ollama_endpoint.present?
    end

    protected

    def api_key
      "local" # Dummy value for availability check
    end

    def default_model
      "llama3"
    end

    private

    def call_api(prompt, options)
      response = HTTParty.post(
        "#{ollama_endpoint}/api/generate",
        headers: { "Content-Type" => "application/json" },
        body: build_request_body(prompt, options).to_json,
        timeout: REQUEST_TIMEOUT
      )

      parse_response(response)
    end

    def build_request_body(prompt, options)
      body = {
        model: model_name,
        prompt: prompt,
        stream: false
      }

      # Only request JSON format if caller expects it
      body[:format] = "json" if options[:json_format]
      body
    end

    def parse_response(response)
      unless response.success?
        return { error: "Ollama request failed: #{response.code}" }
      end

      parsed = response.parsed_response

      {
        content: parsed["response"],
        input_tokens: parsed["prompt_eval_count"],
        output_tokens: parsed["eval_count"]
      }
    end

    def build_response(result, latency_ms)
      if result[:error]
        error_response(
          error: result[:error],
          latency_ms: latency_ms,
          error_type: "http_error"
        )
      else
        success_response(
          content: result[:content],
          latency_ms: latency_ms,
          input_tokens: result[:input_tokens],
          output_tokens: result[:output_tokens]
        )
      end
    end

    def handle_error(exception)
      Rails.logger.error("Ollama request failed: #{exception.message}")

      notify_error(exception, operation: "run", error_type: "request_failed", endpoint: ollama_endpoint)

      error_response(
        error: exception.message,
        latency_ms: 0,
        error_type: exception.class.name
      )
    end

    def ollama_endpoint
      db_config&.api_endpoint || "http://localhost:11434"
    end
  end
end
