# frozen_string_literal: true

# Service for recording AI extraction calls with full observability
#
# Wraps AI extraction calls to capture timing, tokens, costs, and full
# request/response payloads for debugging and analytics.
#
# @example
#   logger = AiExtractionLoggerService.new(
#     scraping_attempt: attempt,
#     job_listing: listing,
#     provider: "anthropic",
#     model: "claude-sonnet-4-20250514"
#   )
#   result = logger.record do |log_context|
#     # Make AI call here
#     # Return { content: "...", input_tokens: 100, output_tokens: 50 }
#   end
class AiExtractionLoggerService
  attr_reader :log

  # Initialize the logger service
  #
  # @param [ScrapingAttempt, nil] scraping_attempt The scraping attempt
  # @param [JobListing, nil] job_listing The job listing
  # @param [String] provider The AI provider name
  # @param [String] model The model identifier
  # @param [Integer, nil] prompt_template_id Optional prompt template ID
  def initialize(scraping_attempt: nil, job_listing: nil, provider:, model:, prompt_template_id: nil)
    @scraping_attempt = scraping_attempt
    @job_listing = job_listing
    @provider = provider
    @model = model
    @prompt_template_id = prompt_template_id
    @log = nil
  end

  # Records an AI extraction call with full observability
  #
  # Captures timing, tokens, and payloads. The block should return a hash with:
  # - content: The extracted content/response
  # - input_tokens: Number of input tokens
  # - output_tokens: Number of output tokens
  # - confidence: Confidence score (0.0-1.0)
  # - error: Error message if failed
  # - error_type: Type of error if failed
  #
  # @param [String, nil] prompt The prompt text (for logging)
  # @param [Integer, nil] html_size Size of HTML content in bytes
  # @yield [log_context] Block that performs the AI call
  # @return [Hash] The result from the block, with logging metadata added
  def record(prompt: nil, html_size: nil)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # Create initial log record
    @log = AiExtractionLog.new(
      scraping_attempt: @scraping_attempt,
      job_listing: @job_listing,
      provider: @provider,
      model: @model,
      prompt_template_id: @prompt_template_id,
      html_content_size: html_size,
      request_payload: { prompt: truncate_for_storage(prompt) },
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
      result.merge(ai_extraction_log_id: @log.id)

    rescue => e
      # Calculate latency even for failures
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      latency_ms = ((end_time - start_time) * 1000).round

      # Record the error
      @log.assign_attributes(
        latency_ms: latency_ms,
        status: classify_exception_status(e),
        error_type: e.class.name,
        error_message: e.message
      )

      @log.save!

      # Re-raise the exception
      raise
    end
  end

  # Records a simple extraction result without wrapping
  #
  # Use this when you've already made the AI call and just want to log it.
  #
  # @param [Hash] result The extraction result
  # @param [Integer] latency_ms Latency in milliseconds
  # @param [String, nil] prompt The prompt text
  # @param [Integer, nil] html_size Size of HTML content
  # @return [AiExtractionLog] The created log record
  def record_result(result, latency_ms:, prompt: nil, html_size: nil)
    @log = AiExtractionLog.create!(
      scraping_attempt: @scraping_attempt,
      job_listing: @job_listing,
      provider: @provider,
      model: @model,
      prompt_template_id: @prompt_template_id,
      html_content_size: html_size,
      request_payload: { prompt: truncate_for_storage(prompt) },
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
  # @param [Hash] result The extraction result
  # @return [Symbol] The status
  def determine_status(result)
    return :rate_limited if result[:rate_limit]
    return :timeout if result[:timeout]
    return :error if result[:error].present?

    :success
  end

  # Classifies exception into status
  #
  # @param [Exception] exception The exception
  # @return [Symbol] The status
  def classify_exception_status(exception)
    message = exception.message.to_s.downcase

    return :rate_limited if message.include?("rate") && message.include?("limit")
    return :timeout if message.include?("timeout") || exception.is_a?(Timeout::Error)

    :error
  end

  # Classifies error message into type
  #
  # @param [String] error The error message
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
  # @param [Hash] result The extraction result
  # @return [Hash] Payload for storage
  def build_response_payload(result)
    payload = {}

    # Include extracted data (truncated for storage)
    payload[:title] = result[:title] if result[:title].present?
    payload[:company] = result[:company] if result[:company].present?
    payload[:confidence] = result[:confidence] if result[:confidence].present?

    # Include raw content if available (truncated)
    if result[:raw_response].present?
      payload[:raw_response] = truncate_for_storage(result[:raw_response])
    end

    # Include error info
    payload[:error] = result[:error] if result[:error].present?

    payload
  end

  # Extracts field names that were successfully populated
  #
  # @param [Hash] result The extraction result
  # @return [Array<String>] Field names
  def extract_field_names(result)
    fields = %i[
      title company job_role description requirements responsibilities
      location remote_type salary_min salary_max salary_currency
      equity_info benefits perks
    ]

    fields.select { |f| result[f].present? }.map(&:to_s)
  end

  # Truncates content for storage to prevent bloat
  #
  # @param [String, nil] content The content to truncate
  # @param [Integer] max_length Maximum length
  # @return [String, nil] Truncated content
  def truncate_for_storage(content, max_length = 50_000)
    return nil if content.nil?
    return content if content.length <= max_length

    content[0...max_length] + "\n\n[TRUNCATED - original length: #{content.length}]"
  end
end

