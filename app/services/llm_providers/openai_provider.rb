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
      if  Setting.helicone_enabled?
        client = OpenAI::Client.new(
          access_token: Rails.application.credentials.dig(:helicone, :api_key),
          base_url: Rails.application.credentials.dig(:helicone, :base_url)
        )
      else
        client = OpenAI::Client.new(access_token: api_key)
      end

      response = client.responses.create(parameters: build_params(prompt, options))
      parse_response(response)
    end

    def build_params(prompt, options)
      input = build_input(prompt, options)

      params = {
        model: model_name,
        input: input,
        temperature: options[:temperature] || temperature_config,
        max_output_tokens: options[:max_tokens] || max_tokens_config(default: 16384)
      }

      params[:previous_response_id] = options[:previous_response_id] if options[:previous_response_id].present?

      if options[:tools].present?
        params[:tools] = options[:tools]
        params[:tool_choice] = options[:tool_choice] if options.key?(:tool_choice)
      end

      params
    end

    def build_input(prompt, options)
      # Supports both legacy prompt string and structured input/messages for tool calling.
      #
      # Legacy: prompt + optional system_message -> [{role, content}, ...]
      # Tool calling: options[:messages] already formatted as [{role, content}, ...]
      input = []

      if options[:messages].present?
        input.concat(Array(options[:messages]))
      else
        system_message = options[:system_message]
        input << { role: "system", content: system_message } if system_message.present?
        # For continuation requests (previous_response_id + tool_outputs), we may not need to add a user message.
        # Never send `content: nil` (OpenAI rejects it with invalid_type).
        prompt_text = prompt.to_s
        input << { role: "user", content: prompt_text } if prompt_text.present?
      end

      Array(options[:tool_outputs]).each do |tool_output|
        call_id = tool_output[:call_id] || tool_output["call_id"] || tool_output[:tool_call_id] || tool_output["tool_call_id"]
        output = tool_output[:output] || tool_output["output"]
        next if call_id.blank?

        # Responses API commonly accepts function_call_output items; keep it provider-specific here.
        input << {
          type: "function_call_output",
          call_id: call_id,
          output: output.is_a?(String) ? output : output.to_json
        }
      end

      input
    end

    def parse_response(response)
      response_data = response.is_a?(Hash) ? response : response.to_h

      content = extract_content(response_data)
      tool_calls = extract_tool_calls(response_data)
      response_id = response_data["id"] || response_data[:id]
      usage = response_data["usage"] || {}

      parsed = {
        content: content,
        tool_calls: tool_calls,
        response_id: response_id,
        raw_response: response_data,
        input_tokens: usage["input_tokens"],
        output_tokens: usage["output_tokens"]
      }

      contract = Assistant::Contracts::ProviderResultContracts::Openai.call(parsed)
      unless contract.success?
        notify_error(RuntimeError.new("OpenAI provider contract failed"), operation: "parse_response", error_type: "contract_failed", contract_errors: contract.errors.to_h)
      end

      parsed
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

    def extract_tool_calls(response_data)
      output = response_data["output"]
      return [] unless output.is_a?(Array)

      calls = output.select { |o| o.is_a?(Hash) && o["type"].to_s.include?("function_call") }

      calls.map do |call|
        {
          id: call["call_id"] || call["id"],
          tool_key: call["name"] || call.dig("function", "name"),
          args: parse_tool_args(call["arguments"] || call.dig("function", "arguments"))
        }
      end.select { |c| c[:tool_key].present? }
    end

    def parse_tool_args(value)
      return {} if value.blank?
      return value if value.is_a?(Hash)

      JSON.parse(value.to_s)
    rescue JSON::ParserError
      {}
    end

    def build_response(result, latency_ms)
      success_response(
        content: result[:content],
        latency_ms: latency_ms,
        input_tokens: result[:input_tokens],
        output_tokens: result[:output_tokens]
      ).merge(
        tool_calls: result[:tool_calls],
        response_id: result[:response_id]
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
      response_body = extract_response_body(exception)
      notify_error(exception, operation: "run", error_type: "request_failed", http_status: http_status)

      error_response(
        error: [ exception.message, response_body.presence ].compact.join(" | "),
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

    def extract_response_body(exception)
      return nil unless exception.respond_to?(:response)

      response = exception.response
      if response.is_a?(Hash)
        body = response[:body] || response["body"]
        body.is_a?(String) ? body : body.to_s
      else
        response.to_s
      end
    rescue StandardError
      nil
    end
  end
end
