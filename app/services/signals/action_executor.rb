# frozen_string_literal: true

module Signals
  # Executes backend signal actions derived from email content
  #
  # Dispatches to specific action handlers based on action type.
  # Only handles actions that require backend processing (not simple URL opens).
  #
  # @example
  #   executor = Signals::ActionExecutor.new(synced_email, user, "start_application")
  #   result = executor.execute
  #   if result[:success]
  #     # Action completed successfully
  #   end
  #
  class ActionExecutor
    attr_reader :synced_email, :user, :action_type, :params

    # Valid backend action types that require user decision
    # Note: URL-based actions are handled directly in the UI via action_links
    # Note: Recruiter/company saving happens automatically during extraction
    # Note: match_application is handled via dropdown in detail panel
    VALID_ACTIONS = %w[
      start_application
    ].freeze

    # Initialize the executor
    #
    # @param synced_email [SyncedEmail] The email with extracted signals
    # @param user [User] The user executing the action
    # @param action_type [String] The action to execute
    # @param params [Hash] Additional parameters for the action
    def initialize(synced_email, user, action_type, params = {})
      @synced_email = synced_email
      @user = user
      @action_type = action_type.to_s
      # Handle both ActionController::Parameters and regular Hash
      @params = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h.with_indifferent_access : params.to_h.with_indifferent_access
    end

    # Executes the action
    #
    # @return [Hash] Result with success status, message, and optional redirect/data
    def execute
      return invalid_action_result unless valid_action?

      action_class = action_handler_class
      return unsupported_action_result unless action_class

      handler = action_class.new(synced_email, user, params)
      handler.execute
    rescue StandardError => e
      Rails.logger.error("Signal action execution failed: #{e.class} - #{e.message}")
      ExceptionNotifier.notify(e, {
        context: "signal_action",
        severity: "error",
        action_type: action_type,
        synced_email_id: synced_email&.id,
        user_id: user&.id
      })
      { success: false, error: e.message }
    end

    # Checks if the action type is valid
    #
    # @return [Boolean]
    def valid_action?
      VALID_ACTIONS.include?(action_type)
    end

    private

    # Returns the handler class for the action type
    #
    # @return [Class, nil]
    def action_handler_class
      case action_type
      when "start_application"
        Actions::StartApplicationAction
      end
    end

    # Result for invalid action type
    #
    # @return [Hash]
    def invalid_action_result
      { success: false, error: "Invalid action type: #{action_type}" }
    end

    # Result for unsupported action type
    #
    # @return [Hash]
    def unsupported_action_result
      { success: false, error: "Action not supported: #{action_type}" }
    end
  end
end
