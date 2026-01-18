# frozen_string_literal: true

# Provides a wrapper for exception notifier systems.
#
# This class provides a centralized interface for exception handling,
# supporting Sentry, Bugsnag, and email notifications with rich context.
#
# @example
#   ExceptionNotifier.notify(exception, {
#     context: 'ai_analysis',
#     ai_provider: 'openai',
#     analyzable_type: 'FeedbackPost',
#     analyzable_id: 123
#   })
#
class ExceptionNotifier
  class << self
    # Notify of an exception with context
    #
    # @param exception [Exception, Hash] The exception or error hash
    # @param options [Hash] Additional context and metadata
    # @option options [String] :context Error context (e.g., 'ai_analysis', 'payment')
    # @option options [String] :severity Severity level ('error', 'warning', 'info')
    # @option options [Hash] :user User information if available
    # @option options [Hash] :ai_context AI-specific metadata for AI errors
    def notify(exception, options = {})
      unless exception.is_a?(Exception)
        if exception.respond_to? :to_hash
          exception = exception.to_hash
          options.merge!(exception)
          message = options.delete(:error_message) || "error in #{options.delete(:error_class)}"
          exception = RuntimeError.new(message)
        else
          exception = RuntimeError.new("Unexpected error")
        end
      end

      payload = extract_i18n_context(exception)
      payload = extract_ai_context(options, payload) if options[:ai_context]

      if Rails.env.development?
        log_development_error(exception, options)
      else
        notify_exception(exception, options, payload)
      end
    end

    # Notify AI-specific errors with rich context
    #
    # @param exception [Exception] The exception
    # @param ai_context [Hash] AI-specific metadata
    # @option ai_context [String] :operation AI operation type (sentiment, entity, summary)
    # @option ai_context [String] :provider_name Provider name
    # @option ai_context [String] :model_identifier Model identifier
    # @option ai_context [Integer] :prompt_id Prompt ID
    # @option ai_context [String] :analyzable_type Type of content analyzed
    # @option ai_context [Integer] :analyzable_id ID of content analyzed
    # @option ai_context [Integer] :account_id Account ID
    def notify_ai_error(exception, ai_context = {})
      notify(exception, {
        context: "ai_#{ai_context[:operation]}",
        severity: ai_context[:severity] || "error",
        ai_context: ai_context,
        tags: {
          ai_operation: ai_context[:operation],
          ai_provider: ai_context[:provider_name],
          ai_model: ai_context[:model_identifier]
        }
      })
    end

    private

    def notify_exception(exception, options = {}, payload)
      notify_sentry(exception, options, payload) if Setting.sentry_enabled? && defined?(Sentry)
      notify_bugsnag(exception, options, payload) if Setting.bugsnag_enabled? && defined?(Bugsnag)
    end

    def notify_sentry(exception, options = {}, payload)
      return unless defined?(Sentry)

      Sentry.with_scope do |scope|
        scope.set_context("context", options)
        scope.set_context(:payload, payload) if payload.present?

        # Set AI-specific context if present
        scope.set_context("ai", options[:ai_context]) if options[:ai_context]

        # Set tags (used for AI and non-AI contexts like billing)
        scope.set_tags(options[:tags]) if options[:tags].present?

        # Set severity level
        scope.set_level(options[:severity]) if options[:severity]

        # Set user context
        if defined?(Current) && Current.respond_to?(:user) && Current.user.present?
          current_email = Current.user.try(:email_address) || Current.user.try(:email)
          scope.set_user(email: current_email, id: Current.user.id)
        elsif options[:user].present?
          scope.set_user(email: options[:user][:email], id: options[:user][:id])
        end

        Sentry.capture_exception(exception)
      end
    end

    def notify_bugsnag(exception, options = {}, payload)
      return unless defined?(Bugsnag)

      if payload.blank?
        return Bugsnag.notify(exception) do |event|
          options.each { |option, data| event.add_metadata(option, data) }
        end
      end

      Bugsnag.notify(exception) do |event|
        event.add_metadata(:context, payload)
        options.each { |option, data| event.add_metadata(option, data) }
      end
    end

    def extract_i18n_context(exception, payload = {})
      return payload unless exception.is_a?(::I18n::MissingTranslationData)

      payload[:translation] = exception&.key
      payload[:translation_options] = exception&.options
      payload
    end

    # Extract AI-specific context from options
    #
    # @param options [Hash] Options hash with ai_context
    # @param payload [Hash] Existing payload
    # @return [Hash] Enhanced payload with AI context
    def extract_ai_context(options, payload = {})
      ai_ctx = options[:ai_context] || {}

      payload[:ai_operation] = ai_ctx[:operation]
      payload[:ai_provider] = ai_ctx[:provider_name]
      payload[:ai_model] = ai_ctx[:model_identifier]
      payload[:ai_prompt_id] = ai_ctx[:prompt_id]
      payload[:analyzable_type] = ai_ctx[:analyzable_type]
      payload[:analyzable_id] = ai_ctx[:analyzable_id]
      payload[:account_id] = ai_ctx[:account_id]
      payload[:tokens_used] = ai_ctx[:tokens_used]
      payload[:processing_time_ms] = ai_ctx[:processing_time_ms]

      payload.compact
    end

    # Log error in development with better formatting
    #
    # @param exception [Exception] The exception
    # @param options [Hash] Additional context
    def log_development_error(exception, options)
      Rails.logger.error "\n" + ("=" * 80)
      Rails.logger.error "EXCEPTION: #{exception.class}"
      Rails.logger.error "MESSAGE: #{exception.message}"
      Rails.logger.error "CONTEXT: #{options[:context]}" if options[:context]

      if options[:ai_context]
        Rails.logger.error "AI OPERATION: #{options[:ai_context][:operation]}"
        Rails.logger.error "AI PROVIDER: #{options[:ai_context][:provider_name]}"
        Rails.logger.error "AI MODEL: #{options[:ai_context][:model_identifier]}"
      end

      Rails.logger.error "\nBACKTRACE:"
      Rails.logger.error exception.backtrace&.first(10)&.join("\n")
      Rails.logger.error "OPTIONS: #{options.except(:ai_context)}" if options.any?
      Rails.logger.error "=" * 80 + "\n"
    end
  end
end
