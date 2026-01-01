# frozen_string_literal: true

module Ai
  # Centralized error reporting for AI/Assistant flows.
  #
  # Use this instead of ad-hoc `Rails.logger.error` so we consistently capture
  # exceptions with enough context to debug: thread/turn/trace/provider/model/log.
  class ErrorReporter
    # @param exception [Exception]
    # @param operation [String, Symbol]
    # @param provider [String, nil]
    # @param model [String, nil]
    # @param user [User, nil]
    # @param thread [Assistant::ChatThread, nil]
    # @param turn [Assistant::Turn, nil]
    # @param trace_id [String, nil]
    # @param llm_api_log_id [Integer, nil]
    # @param extra [Hash]
    def self.notify(exception, operation:, provider: nil, model: nil, user: nil, thread: nil, turn: nil, trace_id: nil, llm_api_log_id: nil, extra: {})
      ai_context = {
        operation: operation.to_s,
        provider_name: provider,
        model_identifier: model,
        user_id: user&.id,
        thread_id: thread&.id,
        thread_uuid: thread&.respond_to?(:uuid) ? thread.uuid : nil,
        turn_id: turn&.id,
        trace_id: trace_id,
        llm_api_log_id: llm_api_log_id
      }.merge(extra.to_h).compact

      ExceptionNotifier.notify_ai_error(exception, ai_context)
    rescue StandardError => e
      Rails.logger.error("[Ai::ErrorReporter] Failed to notify: #{e.class}: #{e.message}")
    end
  end
end
