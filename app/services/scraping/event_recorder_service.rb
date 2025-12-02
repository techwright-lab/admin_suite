# frozen_string_literal: true

module Scraping
  # Service for recording scraping pipeline events
  #
  # Wraps each step of the extraction process to capture timing, payloads,
  # and status for complete observability.
  #
  # @example
  #   recorder = Scraping::EventRecorderService.new(attempt)
  #   result = recorder.record(:html_fetch, step: 1, input: { url: url }) do |event|
  #     html = fetch_html(url)
  #     event.set_output(html_size: html.bytesize, http_status: 200)
  #     html
  #   end
  class EventRecorderService
    attr_reader :scraping_attempt, :job_listing, :current_step

    # Initialize the recorder with a scraping attempt
    #
    # @param [ScrapingAttempt] scraping_attempt The scraping attempt to record events for
    # @param [JobListing, nil] job_listing Optional job listing reference
    def initialize(scraping_attempt, job_listing: nil)
      @scraping_attempt = scraping_attempt
      @job_listing = job_listing || scraping_attempt.job_listing
      @current_step = 0
    end

    # Records an event for a pipeline step
    #
    # Wraps the block with timing and captures input/output payloads.
    # If the block raises an exception, records a failure and re-raises.
    #
    # @param [Symbol] event_type The type of event (from ScrapingEvent::EVENT_TYPES)
    # @param [Integer, nil] step Override step order (auto-increments if nil)
    # @param [Hash] input Input payload to record
    # @param [Hash] metadata Additional metadata
    # @yield [EventContext] Block that performs the step
    # @return [Object] Return value from the block
    def record(event_type, step: nil, input: {}, metadata: {})
      @current_step = step || (@current_step + 1)

      event = create_event(event_type, input, metadata)
      context = EventContext.new(event)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      begin
        result = yield(context) if block_given?

        # Calculate duration
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        duration_ms = ((end_time - start_time) * 1000).round

        # Update event with success
        event.update!(
          status: :success,
          completed_at: Time.current,
          duration_ms: duration_ms,
          output_payload: context.output_data.merge(output_payload_from_result(result))
        )

        result
      rescue => e
        # Calculate duration even for failures
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        duration_ms = ((end_time - start_time) * 1000).round

        # Update event with failure
        event.update!(
          status: :failed,
          completed_at: Time.current,
          duration_ms: duration_ms,
          error_type: e.class.name,
          error_message: e.message,
          output_payload: context.output_data
        )

        raise
      end
    end

    # Records a simple event without wrapping a block
    #
    # Useful for recording events that don't have a distinct start/end.
    #
    # @param [Symbol] event_type The type of event
    # @param [Symbol] status The event status (:success, :failed, :skipped)
    # @param [Hash] input Input payload
    # @param [Hash] output Output payload
    # @param [Hash] metadata Additional metadata
    # @param [String, nil] error_message Error message if failed
    # @param [String, nil] error_type Error type if failed
    # @return [ScrapingEvent] The created event
    def record_simple(event_type, status:, input: {}, output: {}, metadata: {}, error_message: nil, error_type: nil)
      @current_step += 1

      ScrapingEvent.create!(
        scraping_attempt: @scraping_attempt,
        job_listing: @job_listing,
        event_type: event_type,
        step_order: @current_step,
        status: status,
        started_at: Time.current,
        completed_at: Time.current,
        duration_ms: 0,
        input_payload: truncate_payload(input),
        output_payload: truncate_payload(output),
        metadata: metadata,
        error_type: error_type,
        error_message: error_message
      )
    end

    # Records a skipped step
    #
    # @param [Symbol] event_type The type of event
    # @param [String] reason Why the step was skipped
    # @param [Hash] metadata Additional metadata
    # @return [ScrapingEvent] The created event
    def record_skipped(event_type, reason:, metadata: {})
      @current_step += 1

      ScrapingEvent.create!(
        scraping_attempt: @scraping_attempt,
        job_listing: @job_listing,
        event_type: event_type,
        step_order: @current_step,
        status: :skipped,
        started_at: Time.current,
        completed_at: Time.current,
        duration_ms: 0,
        input_payload: {},
        output_payload: { skipped_reason: reason },
        metadata: metadata
      )
    end

    # Records a completion event
    #
    # @param [Hash] summary Summary of the extraction
    # @return [ScrapingEvent] The created event
    def record_completion(summary: {})
      record_simple(
        :completion,
        status: :success,
        output: summary,
        metadata: { total_steps: @current_step }
      )
    end

    # Records a failure event
    #
    # @param [String] message Failure message
    # @param [String, nil] error_type Type of error
    # @param [Hash] details Additional failure details
    # @return [ScrapingEvent] The created event
    def record_failure(message:, error_type: nil, details: {})
      record_simple(
        :failure,
        status: :failed,
        output: details,
        error_message: message,
        error_type: error_type,
        metadata: { total_steps: @current_step }
      )
    end

    private

    # Creates a new event record
    #
    # @param [Symbol] event_type The type of event
    # @param [Hash] input Input payload
    # @param [Hash] metadata Additional metadata
    # @return [ScrapingEvent] The created event
    def create_event(event_type, input, metadata)
      ScrapingEvent.create!(
        scraping_attempt: @scraping_attempt,
        job_listing: @job_listing,
        event_type: event_type,
        step_order: @current_step,
        status: :started,
        started_at: Time.current,
        input_payload: truncate_payload(input),
        output_payload: {},
        metadata: metadata
      )
    end

    # Extracts output payload from a result
    #
    # @param [Object] result The result to extract from
    # @return [Hash] Extracted payload
    def output_payload_from_result(result)
      return {} unless result.is_a?(Hash)

      # Only include relevant keys, not the entire result
      safe_keys = %i[
        success error confidence html_size http_status
        extracted_fields provider model tokens_used
        title company location
      ]

      result.slice(*safe_keys).transform_values { |v| truncate_value(v) }
    end

    # Truncates a payload to prevent excessive storage
    #
    # @param [Hash] payload The payload to truncate
    # @return [Hash] Truncated payload
    def truncate_payload(payload)
      return {} unless payload.is_a?(Hash)

      payload.transform_values { |v| truncate_value(v) }
    end

    # Truncates a single value
    #
    # @param [Object] value The value to truncate
    # @return [Object] Truncated value
    def truncate_value(value)
      case value
      when String
        value.length > 10_000 ? "#{value[0...10_000]}... [TRUNCATED]" : value
      when Hash
        value.transform_values { |v| truncate_value(v) }
      when Array
        value.first(100).map { |v| truncate_value(v) }
      else
        value
      end
    end

    # Context object passed to the block for setting output
    class EventContext
      attr_reader :output_data

      def initialize(event)
        @event = event
        @output_data = {}
      end

      # Sets output data for the event
      #
      # @param [Hash] data The output data
      def set_output(data)
        @output_data.merge!(data)
      end

      # Adds to output data
      #
      # @param [Symbol, String] key The key
      # @param [Object] value The value
      def add_output(key, value)
        @output_data[key] = value
      end
    end
  end
end

