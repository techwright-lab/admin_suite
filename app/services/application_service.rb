# frozen_string_literal: true

# Base class for all application services.
#
# Provides common error notification, logging, and utility methods.
#
# @example Basic service
#   class MyService < ApplicationService
#     def call
#       # do work
#     rescue StandardError => e
#       notify_error(e, context: "my_service")
#       raise
#     end
#   end
#
# @example AI-related service
#   class MyAiService < ApplicationService
#     def call
#       result = call_llm_provider
#     rescue StandardError => e
#       notify_ai_error(e, operation: "my_ai_operation", provider: "openai")
#       raise
#     end
#   end
#
class ApplicationService
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

  # Logs a warning message with service context
  #
  # @param message [String] The warning message
  # @return [void]
  def log_warning(message)
    Rails.logger.warn("[#{self.class.name}] #{message}")
  end

  # Logs an error message with service context
  #
  # @param message [String] The error message
  # @return [void]
  def log_error(message)
    Rails.logger.error("[#{self.class.name}] #{message}")
  end

  # Logs an info message with service context
  #
  # @param message [String] The info message
  # @return [void]
  def log_info(message)
    Rails.logger.info("[#{self.class.name}] #{message}")
  end

  # Safely executes a block, catching and logging errors without re-raising
  #
  # @param fallback [Object] Value to return if block fails
  # @param context [String, nil] Error context for notification (if provided, error is notified)
  # @yield The block to execute
  # @return [Object] Block result or fallback value
  def safely(fallback: nil, context: nil)
    yield
  rescue StandardError => e
    log_warning("#{e.class}: #{e.message}")
    notify_error(e, context: context) if context
    fallback
  end

  # Class-level call method for convenient invocation
  #
  # @example
  #   MyService.call(arg1, arg2)
  #   # equivalent to: MyService.new(arg1, arg2).call
  #
  def self.call(...)
    new(...).call
  end
end
