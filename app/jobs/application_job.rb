class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  protected

  # Notifies of a general error with context
  #
  # @param exception [Exception] The exception to report
  # @param context [String] Error context (e.g., 'payment', 'sync')
  # @param severity [String] Severity level ('error', 'warning', 'info')
  # @param user [User, nil] User associated with the error
  # @param extra [Hash] Additional context
  # @return [void]
  def notify_error(exception, context:, severity: "error", user: nil, **extra)
    user_info = case user
    when User
      { id: user.id, email: user.email_address }
    when Hash
      user
    end

    ExceptionNotifier.notify(exception, {
      context: context,
      severity: severity,
      user: user_info
    }.merge(extra).compact)
  end

  # Notifies of an AI-related error with AI-specific context
  #
  # @param exception [Exception] The exception to report
  # @param operation [String, Symbol] AI operation type
  # @param provider [String, nil] LLM provider name
  # @param model [String, nil] Model identifier
  # @param loggable [ApplicationRecord, nil] The record being processed
  # @param severity [String] Severity level
  # @param extra [Hash] Additional context
  # @return [void]
  def notify_ai_error(exception, operation:, provider: nil, model: nil, loggable: nil, severity: "error", **extra)
    ai_context = {
      operation: operation.to_s,
      provider_name: provider,
      model_identifier: model,
      analyzable_type: loggable&.class&.name,
      analyzable_id: loggable&.id,
      severity: severity
    }.merge(extra.to_h).compact

    ExceptionNotifier.notify_ai_error(exception, ai_context)
  end

  # Logs an error and notifies, then optionally re-raises
  #
  # @param exception [Exception] The exception
  # @param context [String] Error context
  # @param user [User, nil] Associated user
  # @param reraise [Boolean] Whether to re-raise the exception
  # @param extra [Hash] Additional context
  # @return [void]
  def handle_error(exception, context:, user: nil, reraise: true, **extra)
    Rails.logger.error("[#{self.class.name}] #{exception.message}")
    notify_error(exception, context: context, user: user, **extra)
    raise exception if reraise
  end
end
