# frozen_string_literal: true

module Signals
  module Observability
    # Best-effort recorder for end-to-end email pipeline runs/events.
    #
    # Mirrors the ScrapingAttempt/ScrapingEvent pattern, but for the Gmail → Signals pipeline.
    class EmailPipelineRecorder < ApplicationService
      def self.start_for(synced_email:, user:, connected_account:, trigger:, mode:, metadata: {})
        run = Signals::EmailPipelineRun.create!(
          synced_email: synced_email,
          user: user,
          connected_account: connected_account,
          status: :started,
          trigger: trigger.to_s,
          mode: mode.to_s,
          started_at: Time.current,
          metadata: metadata || {}
        )
        new(run)
      end

      def self.for_run(run)
        return nil unless run
        new(run)
      end

      def initialize(run)
        @run = run
      end

      attr_reader :run

      # Records a simple point-in-time event.
      def event!(event_type:, status:, input_payload: {}, output_payload: {}, error: nil, metadata: {})
        step_order = run.next_step_order
        now = Time.current

        Signals::EmailPipelineEvent.create!(
          run: run,
          synced_email: run.synced_email,
          interview_application: run.synced_email.interview_application,
          step_order: step_order,
          event_type: event_type.to_s,
          status: status.to_s,
          started_at: now,
          completed_at: now,
          duration_ms: 0,
          input_payload: input_payload || {},
          output_payload: output_payload || {},
          error_type: error&.class&.name,
          error_message: error&.message,
          metadata: metadata || {}
        )
      rescue StandardError => e
        log_warning("EmailPipelineRecorder event failed: run_id=#{run&.id} #{e.class}: #{e.message}")
        nil
      end

      # Measures a step event around a block, capturing duration and status.
      #
      # If the block returns a Hash, it is stored as output_payload. Otherwise it is stored as:
      # { \"result\" => <returned value> }.
      # @param output_payload_override [Hash, Proc, nil]
      #   - Hash: stored as output_payload
      #   - Proc: called with the block result, stored output
      def measure(event_type, input_payload: {}, output_payload_override: nil, metadata: {})
        step_order = run.next_step_order
        started_at = Time.current
        start_monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        event = Signals::EmailPipelineEvent.create!(
          run: run,
          synced_email: run.synced_email,
          interview_application: run.synced_email.interview_application,
          step_order: step_order,
          event_type: event_type.to_s,
          status: :started,
          started_at: started_at,
          input_payload: input_payload || {},
          output_payload: {},
          metadata: metadata || {}
        )

        result = yield

        completed_at = Time.current
        end_monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        duration_ms = ((end_monotonic - start_monotonic) * 1000).round

        output_payload =
          if output_payload_override.respond_to?(:call)
            output_payload_override.call(result)
          else
            output_payload_override
          end
        output_payload ||= (result.is_a?(Hash) ? result : { "result" => result })
        event.update!(
          status: :success,
          completed_at: completed_at,
          duration_ms: duration_ms,
          output_payload: output_payload || {}
        )

        result
      rescue StandardError => e
        completed_at = Time.current
        duration_ms =
          begin
            end_monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            ((end_monotonic - start_monotonic) * 1000).round
          rescue StandardError
            nil
          end

        begin
          event&.update!(
            status: :failed,
            completed_at: completed_at,
            duration_ms: duration_ms,
            error_type: e.class.name,
            error_message: e.message,
            output_payload: { "error" => e.message }
          )
        rescue StandardError => update_err
          log_warning("EmailPipelineRecorder failed to update event: run_id=#{run&.id} #{update_err.class}: #{update_err.message}")
        end

        raise
      end

      def finish_success!(metadata: {})
        finish!(status: :success, metadata: metadata)
      end

      def finish_failed!(exception, metadata: {})
        finish!(
          status: :failed,
          error_type: exception.class.name,
          error_message: exception.message,
          metadata: metadata
        )
      end

      def finish!(status:, error_type: nil, error_message: nil, metadata: {})
        completed_at = Time.current
        duration_ms = ((completed_at - run.started_at) * 1000).round if run.started_at

        merged = (run.metadata.is_a?(Hash) ? run.metadata.deep_dup : {})
        merged.merge!(metadata || {})

        run.update!(
          status: status,
          completed_at: completed_at,
          duration_ms: duration_ms,
          error_type: error_type,
          error_message: error_message,
          metadata: merged
        )
      rescue StandardError => e
        log_warning("EmailPipelineRecorder finish failed: run_id=#{run&.id} #{e.class}: #{e.message}")
        nil
      end
    end
  end
end
