# frozen_string_literal: true

module Signals
  module Actions
    # Base class for signal actions
    #
    # Provides common functionality for all action handlers.
    # Subclasses must implement the #execute method.
    #
    class BaseAction
      attr_reader :synced_email, :user, :params

      # Initialize the action
      #
      # @param synced_email [SyncedEmail] The email with extracted signals
      # @param user [User] The user executing the action
      # @param params [Hash] Additional parameters
      def initialize(synced_email, user, params = {})
        @synced_email = synced_email
        @user = user
        @params = params.with_indifferent_access
      end

      # Executes the action
      #
      # @return [Hash] Result with success status and relevant data
      def execute
        raise NotImplementedError, "Subclasses must implement #execute"
      end

      protected

      # Returns the extracted company name
      #
      # @return [String, nil]
      def company_name
        synced_email.signal_company_name
      end

      # Returns the extracted company website
      #
      # @return [String, nil]
      def company_website
        synced_email.signal_company_website
      end

      # Returns the extracted careers URL
      #
      # @return [String, nil]
      def careers_url
        synced_email.signal_company_careers_url
      end

      # Returns the extracted job title
      #
      # @return [String, nil]
      def job_title
        synced_email.signal_job_title
      end

      # Returns the extracted job URL
      #
      # @return [String, nil]
      def job_url
        synced_email.signal_job_url
      end

      # Returns the first scheduling link from action_links
      #
      # @return [String, nil]
      def scheduling_link
        return nil unless synced_email.signal_action_links.is_a?(Array)
        
        # Find first link with priority 1 (scheduling links) or label containing "schedule"
        scheduling = synced_email.signal_action_links.find do |link|
          link["priority"] == 1 || link["action_label"]&.downcase&.include?("schedule")
        end
        scheduling&.dig("url")
      end

      # Returns the extracted recruiter name
      #
      # @return [String, nil]
      def recruiter_name
        synced_email.signal_recruiter_name
      end

      # Returns the extracted recruiter email
      #
      # @return [String, nil]
      def recruiter_email
        synced_email.signal_recruiter_email || synced_email.from_email
      end

      # Builds a success result
      #
      # @param message [String] Success message
      # @param data [Hash] Additional data
      # @return [Hash]
      def success_result(message, data = {})
        { success: true, message: message }.merge(data)
      end

      # Builds a failure result
      #
      # @param error [String] Error message
      # @return [Hash]
      def failure_result(error)
        { success: false, error: error }
      end

      # Builds a redirect result
      #
      # @param url [String] URL to redirect to
      # @param message [String] Optional message
      # @return [Hash]
      def redirect_result(url, message = nil)
        result = { success: true, redirect_url: url, external: true }
        result[:message] = message if message
        result
      end
    end
  end
end
