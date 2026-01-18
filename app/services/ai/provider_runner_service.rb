# frozen_string_literal: true

module Ai
  # Service for running LLM providers with standardized logging and fallback.
  #
  # Wraps provider execution with ApiLoggerService.record, captures
  # provider response metadata, and supports custom parsing/acceptance.
  #
  # @example
  #   runner = Ai::ProviderRunnerService.new(
  #     provider_chain: providers,
  #     prompt: prompt,
  #     content_size: content_size,
  #     system_message: system_message,
  #     provider_for: ->(name) { provider_for(name) },
  #     logger_builder: ->(name, provider) { build_logger(name, provider) }
  #   )
  #   result = runner.run do |response|
  #     parsed = parse_response(response[:content])
  #     log_data = { confidence: parsed[:confidence_score] }
  #     accept = parsed[:confidence_score].to_f >= 0.6
  #     [ parsed, log_data, accept ]
  #   end
  #
  # @return [Hash] result with success/error status
  class ProviderRunnerService < ApplicationService
    # @param provider_chain [Array<String>] Ordered provider names
    # @param prompt [String] Prompt text
    # @param content_size [Integer] Content size for logging
    # @param system_message [String, nil] System message for providers
    # @param provider_for [Proc] Proc that returns provider instance
    # @param logger_builder [Proc] Proc that returns ApiLoggerService
    # @param run_options [Hash] Additional provider.run options
    # @param on_exception [Proc, nil] Optional exception handler
    def initialize(
      provider_chain:,
      prompt:,
      content_size:,
      system_message: nil,
      provider_for:,
      logger_builder:,
      run_options: {},
      on_exception: nil,
      on_rate_limit: nil,
      on_error: nil,
      operation: nil,
      loggable: nil,
      user: nil,
      error_context: nil
    )
      @provider_chain = provider_chain
      @prompt = prompt
      @content_size = content_size
      @system_message = system_message
      @provider_for = provider_for
      @logger_builder = logger_builder
      @run_options = run_options
      @on_exception = on_exception
      @on_rate_limit = on_rate_limit
      @on_error = on_error
      @operation = operation
      @loggable = loggable
      @user = user
      @error_context = error_context
    end

    # Runs providers in order until one is accepted.
    #
    # @yieldparam response [Hash] Provider response
    # @yieldreturn [Array] [parsed, log_data, accept]
    # @return [Hash] Result with status, parsed, log id, and metadata
    def run
      provider_chain.each do |provider_name|
        provider = provider_for.call(provider_name)
        next unless provider&.available?

        response_model = nil
        accept = true
        parsed = nil
        logger = logger_builder.call(provider_name, provider)

        result = logger.record(prompt: prompt, content_size: content_size) do
          response = provider.run(prompt, **provider_run_options)
          response_model = response[:model]

          if response[:rate_limit]
            on_rate_limit&.call(response, provider_name, logger)
            next error_log_data(
              response,
              error: "rate_limited",
              rate_limit: true
            )
          end

          if response[:error]
            on_error&.call(response, provider_name, logger)
            next error_log_data(
              response,
              error: response[:error],
              error_type: response[:error_type]
            )
          end

          parsed, log_data, accept = yield(response)
          log_data ||= {}
          log_data.merge(standard_response_data(response))
        end

        next if result[:rate_limit] || result[:error]
        next if accept == false

        model_name = response_model || (provider.respond_to?(:model_name) ? provider.model_name : "unknown")
        return {
          success: true,
          provider: provider_name,
          model: model_name,
          parsed: parsed,
          llm_api_log_id: result[:llm_api_log_id],
          latency_ms: result[:latency_ms],
          result: result
        }
      rescue StandardError => e
        handle_exception(e, provider_name, logger)
        next
      end

      { success: false, error: "All providers failed" }
    end

    private

    attr_reader :provider_chain,
      :prompt,
      :content_size,
      :system_message,
      :provider_for,
      :logger_builder,
      :run_options,
      :on_exception,
      :on_rate_limit,
      :on_error,
      :operation,
      :loggable,
      :user,
      :error_context

    # Builds options for provider.run
    #
    # @return [Hash]
    def provider_run_options
      base = run_options.dup
      base[:system_message] = system_message if system_message.present?
      base
    end

    # Builds standard log data for error results.
    #
    # @param response [Hash]
    # @param error [String]
    # @param error_type [String, nil]
    # @param rate_limit [Boolean]
    # @return [Hash]
    def error_log_data(response, error:, error_type: nil, rate_limit: false)
      standard_response_data(response).merge(
        error: error,
        error_type: error_type,
        rate_limit: rate_limit
      )
    end

    # Builds standard log data for responses.
    #
    # @param response [Hash]
    # @return [Hash]
    def standard_response_data(response)
      {
        input_tokens: response[:input_tokens],
        output_tokens: response[:output_tokens],
        raw_response: response[:content],
        provider_request: response[:provider_request],
        provider_response: response[:provider_response],
        provider_error_response: response[:provider_error_response],
        http_status: response[:http_status],
        response_headers: response[:response_headers],
        provider_endpoint: response[:provider_endpoint]
      }
    end

    def handle_exception(exception, provider_name, logger)
      return on_exception.call(exception, provider_name, logger) if on_exception

      latency_ms = logger&.log&.latency_ms
      model_name = logger&.log&.model
      extra = { processing_time_ms: latency_ms }.merge(error_context.to_h).compact

      if operation.present?
        notify_ai_error(
          exception,
          operation: operation,
          provider: provider_name,
          model: model_name,
          loggable: loggable,
          severity: extra.delete(:severity) || "error",
          **extra
        )
      else
        notify_error(
          exception,
          context: "provider_runner",
          severity: extra.delete(:severity) || "error",
          user: user,
          **extra
        )
      end
    end
  end
end
