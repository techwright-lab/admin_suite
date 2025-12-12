# frozen_string_literal: true

module LlmProviders
  # Base provider class for LLM integrations
  #
  # Providers are responsible for:
  # - Making API calls to LLM services
  # - Error handling and rate limiting
  # - Instrumentation (latency, token usage)
  #
  # Providers are NOT responsible for:
  # - Building prompts (done by services)
  # - Parsing responses (done by services)
  #
  # @abstract Subclass and override {#run} to implement
  class BaseProvider
    # Logging context attributes (set by caller for observability)
    attr_accessor :scraping_attempt, :job_listing

    # Sends a prompt to the LLM and returns the response
    #
    # @param prompt [String] The prompt text to send
    # @param options [Hash] Optional parameters
    #   @option options [Integer] :max_tokens Maximum tokens in response
    #   @option options [Float] :temperature Temperature setting (0-1)
    #   @option options [String] :system_message Optional system message
    # @return [Hash] Result hash with:
    #   - :content [String] The LLM response text
    #   - :provider [String] Provider name
    #   - :model [String] Model used
    #   - :input_tokens [Integer] Input token count
    #   - :output_tokens [Integer] Output token count
    #   - :latency_ms [Integer] Request latency in milliseconds
    #   - :error [String, nil] Error message if failed
    #   - :rate_limit [Boolean] True if rate limited
    # @raise [NotImplementedError] Must be implemented by subclass
    def run(prompt, options = {})
      raise NotImplementedError, "#{self.class} must implement #run"
    end

    # Checks if the provider is available and configured
    #
    # @return [Boolean] True if provider can be used
    def available?
      api_key.present? && enabled?
    end

    # Returns the provider name (e.g., "anthropic", "openai")
    #
    # @return [String] Provider name
    def provider_name
      self.class.name.demodulize.gsub("Provider", "").downcase
    end

    # Returns the model name being used
    #
    # @return [String] Model name
    def model_name
      db_config&.llm_model || config["model"] || default_model
    end

    protected

    # Returns the API key for this provider
    #
    # @return [String, nil] API key or nil if not configured
    # @raise [NotImplementedError] Must be implemented by subclass
    def api_key
      raise NotImplementedError, "#{self.class} must implement #api_key"
    end

    # Returns the default model for this provider
    #
    # @return [String] Default model name
    def default_model
      "unknown"
    end

    # Returns the database configuration for this provider
    #
    # @return [LlmProviderConfig, nil] Provider configuration or nil
    def db_config
      @db_config ||= ::LlmProviderConfig.by_provider_type(provider_name).enabled.first
    end

    # Returns the configuration hash for this provider
    #
    # @return [Hash] Provider configuration
    def config
      @config ||= db_config&.to_config || {}
    end

    # Checks if provider is enabled in configuration
    #
    # @return [Boolean] True if enabled
    def enabled?
      db_config&.enabled? || false
    end

    # Returns max tokens from config or default
    #
    # @param default [Integer] Default value
    # @return [Integer] Max tokens
    def max_tokens_config(default: 4096)
      db_config&.max_tokens || default
    end

    # Returns temperature from config or default
    #
    # @param default [Float] Default value
    # @return [Float] Temperature
    def temperature_config(default: 0)
      db_config&.temperature || default
    end

    # Measures execution time and returns latency in ms
    #
    # @yield Block to measure
    # @return [Array] [result, latency_ms]
    def with_timing
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      latency_ms = ((end_time - start_time) * 1000).round
      [ result, latency_ms ]
    end

    # Builds a success response hash
    #
    # @param content [String] Response content
    # @param latency_ms [Integer] Latency in milliseconds
    # @param input_tokens [Integer, nil] Input token count
    # @param output_tokens [Integer, nil] Output token count
    # @return [Hash] Success response
    def success_response(content:, latency_ms:, input_tokens: nil, output_tokens: nil)
      {
        content: content,
        provider: provider_name,
        model: model_name,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        latency_ms: latency_ms
      }
    end

    # Builds an error response hash
    #
    # @param error [String] Error message
    # @param latency_ms [Integer] Latency in milliseconds
    # @param error_type [String] Error classification
    # @param rate_limit [Boolean] Whether this is a rate limit error
    # @param retry_after [Integer, nil] Seconds to wait before retry
    # @return [Hash] Error response
    def error_response(error:, latency_ms:, error_type: nil, rate_limit: false, retry_after: nil)
      response = {
        content: nil,
        error: error,
        provider: provider_name,
        model: model_name,
        error_type: error_type,
        latency_ms: latency_ms
      }
      response[:rate_limit] = true if rate_limit
      response[:retry_after] = retry_after if retry_after
      response
    end

    # Notifies about an AI error
    #
    # @param exception [Exception] The exception
    # @param context [Hash] Additional context
    def notify_error(exception, context = {})
      ExceptionNotifier.notify_ai_error(exception, {
        provider_name: provider_name,
        model_identifier: model_name
      }.merge(context))
    end
  end
end
