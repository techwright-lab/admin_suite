# frozen_string_literal: true

module Ai
  # Service for recording LLM API calls with full observability
  #
  # Wraps LLM calls to capture timing, tokens, costs, and full
  # request/response payloads for debugging and analytics.
  #
  # @example
  #   logger = Ai::ApiLoggerService.new(
  #     operation_type: :job_extraction,
  #     loggable: job_listing,
  #     provider: "anthropic",
  #     model: "claude-sonnet-4-20250514"
  #   )
  #   result = logger.record do |log_context|
  #     # Make AI call here
  #     # Return { content: "...", input_tokens: 100, output_tokens: 50 }
  #   end
  #
  class ApiLoggerService
    attr_reader :log

    # Initialize the logger service
    #
    # @param operation_type [String, Symbol] The type of operation (job_extraction, email_extraction, resume_extraction)
    # @param loggable [ApplicationRecord, nil] The object being processed (JobListing, Opportunity, UserResume)
    # @param provider [String] The AI provider name
    # @param model [String] The model identifier
    # @param llm_prompt [Ai::LlmPrompt, nil] Optional prompt template used
    def initialize(operation_type:, loggable: nil, provider:, model:, llm_prompt: nil)
      @operation_type = operation_type.to_s
      @loggable = loggable
      @provider = provider
      @model = model
      @llm_prompt = llm_prompt
      @log = nil
    end

    # Records an LLM API call with full observability
    #
    # Captures timing, tokens, and payloads. The block should return a hash with:
    # - content: The extracted content/response
    # - input_tokens: Number of input tokens
    # - output_tokens: Number of output tokens
    # - confidence: Confidence score (0.0-1.0)
    # - error: Error message if failed
    # - error_type: Type of error if failed
    #
    # @param prompt [String, nil] The prompt text (for logging)
    # @param content_size [Integer, nil] Size of content in bytes
    # @yield [log_context] Block that performs the AI call
    # @return [Hash] The result from the block, with logging metadata added
    def record(prompt: nil, content_size: nil)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Create initial log record
      @log = Ai::LlmApiLog.new(
        operation_type: @operation_type,
        loggable: @loggable,
        llm_prompt: @llm_prompt,
        provider: @provider,
        model: @model,
        content_size: content_size,
        request_payload: build_request_payload(prompt: prompt),
        status: :success
      )

      begin
        # Execute the AI call
        result = yield(self)

        # Calculate latency
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        latency_ms = ((end_time - start_time) * 1000).round

        # Update log with results
        @log.assign_attributes(
          latency_ms: latency_ms,
          input_tokens: result[:input_tokens],
          output_tokens: result[:output_tokens],
          confidence_score: result[:confidence],
          request_payload: build_request_payload(prompt: prompt, result: result),
          response_payload: build_response_payload(result),
          extracted_fields: extract_field_names(result),
          status: determine_status(result)
        )

        # Handle errors in result
        if result[:error].present?
          @log.assign_attributes(
            error_message: result[:error],
            error_type: result[:error_type] || classify_error(result[:error])
          )
        end

        @log.save!

        # Return result with log reference
        result.merge(llm_api_log_id: @log.id)

      rescue => e
        # Calculate latency even for failures
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        latency_ms = ((end_time - start_time) * 1000).round

        # Record the error
        @log.assign_attributes(
          latency_ms: latency_ms,
          status: classify_exception_status(e),
          error_type: e.class.name,
          error_message: e.message,
          response_payload: build_exception_response_payload(e)
        )

        @log.save!

        # Notify with rich context for easier debugging (thread/trace/log ids, etc).
        # This is intentionally best-effort so logging never hides the original exception.
        begin
          Ai::ErrorReporter.notify(
            e,
            operation: @operation_type,
            provider: @provider,
            model: @model,
            user: @loggable.is_a?(User) ? @loggable : nil,
            thread: @loggable.is_a?(Assistant::ChatThread) ? @loggable : nil,
            trace_id: nil,
            llm_api_log_id: @log.id,
            extra: { llm_prompt_id: @llm_prompt&.id, loggable_type: @loggable&.class&.name, loggable_id: @loggable&.id }
          )
        rescue StandardError
          # best-effort only
        end

        # Re-raise the exception
        raise
      end
    end

    # Records a simple result without wrapping
    #
    # Use this when you've already made the AI call and just want to log it.
    #
    # @param result [Hash] The extraction result
    # @param latency_ms [Integer] Latency in milliseconds
    # @param prompt [String, nil] The prompt text
    # @param content_size [Integer, nil] Size of content
    # @return [Ai::LlmApiLog] The created log record
    def record_result(result, latency_ms:, prompt: nil, content_size: nil)
      @log = Ai::LlmApiLog.create!(
        operation_type: @operation_type,
        loggable: @loggable,
        llm_prompt: @llm_prompt,
        provider: @provider,
        model: @model,
        content_size: content_size,
        request_payload: build_request_payload(prompt: prompt, result: result),
        response_payload: build_response_payload(result),
        latency_ms: latency_ms,
        input_tokens: result[:input_tokens],
        output_tokens: result[:output_tokens],
        confidence_score: result[:confidence],
        extracted_fields: extract_field_names(result),
        status: determine_status(result),
        error_message: result[:error],
        error_type: result[:error_type] || (result[:error].present? ? classify_error(result[:error]) : nil)
      )
    end

    private

    # Determines the status based on the result
    #
    # @param result [Hash] The extraction result
    # @return [Symbol] The status
    def determine_status(result)
      return :rate_limited if result[:rate_limit]
      return :timeout if result[:timeout]
      return :error if result[:error].present?

      :success
    end

    # Classifies exception into status
    #
    # @param exception [Exception] The exception
    # @return [Symbol] The status
    def classify_exception_status(exception)
      message = exception.message.to_s.downcase

      return :rate_limited if message.include?("rate") && message.include?("limit")
      return :timeout if message.include?("timeout") || exception.is_a?(Timeout::Error)

      :error
    end

    # Classifies error message into type
    #
    # @param error [String] The error message
    # @return [String] Error type
    def classify_error(error)
      return "rate_limit" if error.to_s.downcase.include?("rate")
      return "timeout" if error.to_s.downcase.include?("timeout")
      return "parsing" if error.to_s.downcase.include?("json") || error.to_s.downcase.include?("parse")
      return "authentication" if error.to_s.downcase.include?("auth") || error.to_s.downcase.include?("key")

      "unknown"
    end

    # Builds response payload for storage
    #
    # Stores comprehensive extraction data for debugging purposes.
    #
    # @param result [Hash] The extraction result
    # @return [Hash] Payload for storage
    def build_response_payload(result)
      payload = {}

      # Provider-native request/response (raw, best-effort) for debugging.
      # These are intentionally separate from parsed/extracted fields.
      if result[:provider_response].present?
        payload[:provider_response] = sanitize_payload_for_storage(result[:provider_response])
      end
      if result[:provider_error_response].present?
        payload[:provider_error_response] = sanitize_payload_for_storage(result[:provider_error_response])
      end
      payload[:http_status] = result[:http_status] if result[:http_status].present?
      if result[:response_headers].present?
        payload[:response_headers] = sanitize_payload_for_storage(result[:response_headers], max_string_length: 10_000)
      end
      payload[:provider_endpoint] = result[:provider_endpoint] if result[:provider_endpoint].present?

      # For assistant operations, store the full text response for debugging/replay.
      if @operation_type.to_s.start_with?("assistant_") && result[:content].present?
        payload[:text] = truncate_for_storage(result[:content], 10_000)
      end

      # Core extraction fields for job extraction
      job_extraction_fields = %i[
        title company job_role description about_company company_culture
        requirements responsibilities location remote_type
        salary_min salary_max salary_currency equity_info benefits perks
        notes
      ]

      # Store all extracted job fields with their values (truncated for long text)
      job_extraction_fields.each do |field|
        next unless result[field].present?

        value = result[field]
        payload[field] = case value
        when String
          truncate_for_display(value, 500)
        when Array, Hash
          value
        else
          value
        end
      end

      # Always include confidence
      payload[:confidence] = result[:confidence] if result[:confidence].present?

      # Interview prep payloads: store small, structured preview fields.
      if @operation_type.to_s.start_with?("interview_prep_")
        payload[:match_label] = result[:match_label] if result[:match_label].present?
        payload[:strong_in] = Array(result[:strong_in]).first(8) if result[:strong_in].present?
        payload[:partial_in] = Array(result[:partial_in]).first(8) if result[:partial_in].present?
        payload[:missing_or_risky] = Array(result[:missing_or_risky]).first(8) if result[:missing_or_risky].present?
        payload[:focus_areas_count] = Array(result.dig(:focus_areas)).size if result[:focus_areas].present?
        payload[:questions_count] = Array(result.dig(:questions)).size if result[:questions].present?
        payload[:strengths_count] = Array(result.dig(:strengths)).size if result[:strengths].present?
      end

      # Include skills summary for resume extraction
      if result[:skills].is_a?(Array)
        payload[:skills_count] = result[:skills].size
        payload[:skills_preview] = result[:skills].first(5).map { |s| s[:name] rescue s.to_s }
      end

      # Include raw LLM response if available (truncated but longer for debugging)
      if result[:raw_response].present?
        payload[:raw_response] = truncate_for_storage(result[:raw_response], 10_000)
      end

      # Include error info
      payload[:error] = result[:error] if result[:error].present?

      # Include any custom sections
      payload[:custom_sections] = result[:custom_sections] if result[:custom_sections].present?

      payload
    end

    # Builds request payload for storage
    #
    # Captures both the "prompt string" and the provider-native request payload
    # (if the caller/provider provides it).
    #
    # @param prompt [String, nil]
    # @param result [Hash, nil]
    # @return [Hash]
    def build_request_payload(prompt:, result: nil)
      payload = {}
      payload[:prompt] = truncate_for_storage(prompt) if prompt.present?

      if result.is_a?(Hash)
        if result[:provider_request].present?
          payload[:provider_request] = sanitize_payload_for_storage(result[:provider_request])
        end
        payload[:provider_endpoint] = result[:provider_endpoint] if result[:provider_endpoint].present?
      end

      payload
    end

    # Attempts to capture a provider/client response from raised exceptions (best-effort).
    #
    # @param exception [Exception]
    # @return [Hash]
    def build_exception_response_payload(exception)
      payload = {
        exception_class: exception.class.name,
        exception_message: exception.message
      }

      if exception.respond_to?(:response)
        payload[:exception_response] = sanitize_payload_for_storage(exception.response, max_string_length: 10_000)
      end
      if exception.respond_to?(:status)
        payload[:http_status] = exception.status
      end

      payload.compact
    rescue StandardError
      { exception_class: exception.class.name, exception_message: exception.message }
    end

    # Sanitizes nested payloads for JSONB storage and UI rendering.
    #
    # - Truncates long strings
    # - Converts SDK objects via `to_h` when available
    # - Limits recursion depth to avoid pathological payloads
    #
    # @param value [Object]
    # @param max_string_length [Integer]
    # @param max_depth [Integer]
    # @param depth [Integer]
    # @return [Object]
    def sanitize_payload_for_storage(value, max_string_length: 50_000, max_depth: 8, depth: 0)
      return nil if value.nil?
      return "[TRUNCATED: max_depth=#{max_depth}]" if depth >= max_depth

      if value.is_a?(String)
        return truncate_for_storage(value, max_string_length)
      end

      if value.is_a?(Numeric) || value == true || value == false
        return value
      end

      if value.is_a?(Hash)
        return value.to_h.each_with_object({}) do |(k, v), acc|
          acc[k.to_s] = sanitize_payload_for_storage(v, max_string_length: max_string_length, max_depth: max_depth, depth: depth + 1)
        end
      end

      if value.is_a?(Array)
        return value.first(200).map { |v| sanitize_payload_for_storage(v, max_string_length: max_string_length, max_depth: max_depth, depth: depth + 1) }
      end

      if value.respond_to?(:to_h)
        return sanitize_payload_for_storage(value.to_h, max_string_length: max_string_length, max_depth: max_depth, depth: depth + 1)
      end

      sanitize_payload_for_storage(value.to_s, max_string_length: max_string_length, max_depth: max_depth, depth: depth + 1)
    end

    # Truncates content for display in UI
    #
    # @param content [String, nil] The content to truncate
    # @param max_length [Integer] Maximum length
    # @return [String, nil] Truncated content
    def truncate_for_display(content, max_length = 500)
      return nil if content.nil?
      return content if content.length <= max_length

      content[0...max_length] + "..."
    end

    # Extracts field names that were successfully populated
    #
    # @param result [Hash] The extraction result
    # @return [Array<String>] Field names
    def extract_field_names(result)
      # Common job extraction fields
      job_fields = %i[
        title company job_role description requirements responsibilities
        location remote_type salary_min salary_max salary_currency
        equity_info benefits perks
      ]

      # Email extraction fields
      email_fields = %i[
        company_name job_role_title job_url recruiter_info key_details
        all_links is_forwarded original_source
      ]

      # Resume extraction fields
      resume_fields = %i[
        skills summary strengths domains
      ]

      all_fields = job_fields + email_fields + resume_fields
      all_fields.select { |f| result[f].present? }.map(&:to_s)
    end

    # Truncates content for storage to prevent bloat
    #
    # @param content [String, nil] The content to truncate
    # @param max_length [Integer] Maximum length
    # @return [String, nil] Truncated content
    def truncate_for_storage(content, max_length = 50_000)
      return nil if content.nil?
      return content if content.length <= max_length

      content[0...max_length] + "\n\n[TRUNCATED - original length: #{content.length}]"
    end
  end
end
