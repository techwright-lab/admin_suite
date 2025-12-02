# frozen_string_literal: true

module LlmProviders
  # Ollama provider for self-hosted LLM job listing extraction
  class OllamaProvider < BaseProvider
    # Extracts structured job data using Ollama's local models
    #
    # @param [String] html_content The HTML content of the job listing
    # @param [String] url The URL of the job listing
    # @return [Hash] Extracted job data with confidence scores
    def extract_job_data(html_content, url)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      prompt = build_extraction_prompt(html_content, url)
      html_size = html_content.bytesize

      response = HTTParty.post(
        "#{ollama_endpoint}/api/generate",
        headers: { "Content-Type" => "application/json" },
        body: {
          model: model_name,
          prompt: prompt,
          stream: false,
          format: "json"
        }.to_json,
        timeout: 120 # Longer timeout for local inference
      )

      # Calculate latency
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      latency_ms = ((end_time - start_time) * 1000).round

      if response.success?
        content = response.parsed_response["response"]
        parsed_data = parse_response(content)

        # Extract token info from Ollama response if available
        prompt_eval_count = response.parsed_response["prompt_eval_count"]
        eval_count = response.parsed_response["eval_count"]

        # Add provider metadata
        result = parsed_data.merge(
          provider: "ollama",
          model: model_name,
          tokens_used: eval_count,
          input_tokens: prompt_eval_count,
          output_tokens: eval_count,
          raw_response: content
        )

        # Log the extraction result
        log_extraction_result(result, latency_ms: latency_ms, prompt: prompt, html_size: html_size)

        result
      else
        result = {
          error: "Ollama request failed: #{response.code}",
          confidence: 0.0,
          provider: "ollama",
          error_type: "http_error"
        }

        log_extraction_result(result, latency_ms: latency_ms, prompt: prompt, html_size: html_size) rescue nil

        result
      end
    rescue => e
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      latency_ms = ((end_time - start_time) * 1000).round rescue 0

      Rails.logger.error("Ollama extraction failed: #{e.message}")

      # Notify exception with AI context
      ExceptionNotifier.notify_ai_error(e, {
        operation: "job_extraction",
        provider_name: "ollama",
        model_identifier: model_name,
        error_type: "extraction_failed",
        url: url,
        endpoint: ollama_endpoint
      })

      result = {
        error: e.message,
        confidence: 0.0,
        provider: "ollama",
        error_type: e.class.name
      }

      log_extraction_result(result, latency_ms: latency_ms, prompt: prompt, html_size: html_size) rescue nil

      result
    end

    # Ollama doesn't require an API key for local deployment
    #
    # @return [Boolean] Always true for Ollama
    def available?
      enabled? && ollama_endpoint.present?
    end

    protected

    # Ollama uses local endpoint, no API key needed
    #
    # @return [String] Dummy value to indicate availability
    def api_key
      "local"
    end

    # Returns the Ollama endpoint URL
    #
    # @return [String] Endpoint URL
    def ollama_endpoint
      db_config&.api_endpoint || "http://localhost:11434"
    end
  end
end
