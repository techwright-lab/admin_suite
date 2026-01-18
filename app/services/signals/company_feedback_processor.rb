# frozen_string_literal: true

module Signals
  # Service for capturing company feedback from various email types
  #
  # This processor creates CompanyFeedback records from emails that contain
  # feedback about the candidate, even if they're not explicit rejection/offer emails.
  # It works as a secondary processor alongside ApplicationStatusProcessor.
  #
  # @example
  #   processor = Signals::CompanyFeedbackProcessor.new(synced_email)
  #   result = processor.process
  #   if result[:success]
  #     # Feedback captured
  #   end
  #
  class CompanyFeedbackProcessor < ApplicationService
    attr_reader :synced_email, :application

    # Initialize the processor
    #
    # @param synced_email [SyncedEmail] The email to process
    def initialize(synced_email)
      @synced_email = synced_email
      @application = synced_email.interview_application
    end

    # Processes the email to create company feedback
    #
    # @return [Hash] Result with success status
    def process
      return skip_result("Email not matched to application") unless application
      return skip_result("Feedback already exists for this email") if feedback_exists_for_email?
      return skip_result("No email content") unless content_available?

      # Check if there's extractable feedback in the email
      feedback_data = extract_feedback_from_signals

      if feedback_data[:has_feedback]
        feedback = create_feedback_record(feedback_data)
        if feedback&.persisted?
          { success: true, feedback: feedback, action: :created }
        else
          { success: false, error: "Failed to create feedback record" }
        end
      else
        skip_result("No feedback content found in email")
      end
    rescue StandardError => e
      notify_error(
        e,
        context: "company_feedback_processor",
        user: synced_email&.user,
        synced_email_id: synced_email&.id,
        application_id: application&.id
      )
      { success: false, error: e.message }
    end

    private

    # Checks if email content is available
    #
    # @return [Boolean]
    def content_available?
      synced_email.body_preview.present? ||
        synced_email.body_html.present? ||
        synced_email.snippet.present?
    end

    # Checks if feedback already exists for this email
    #
    # @return [Boolean]
    def feedback_exists_for_email?
      CompanyFeedback.exists?(source_email_id: synced_email.id)
    end

    # Returns skip result
    #
    # @param reason [String]
    # @return [Hash]
    def skip_result(reason)
      { success: false, skipped: true, reason: reason }
    end

    # Extracts feedback data from already-extracted signals
    #
    # @return [Hash]
    def extract_feedback_from_signals
      # Use existing extracted data if available
      extracted = synced_email.extracted_data || {}

      # Check if there's feedback in the extracted signals
      feedback_text = extracted.dig("feedback", "feedback_text") ||
                      extracted.dig("feedback_text")
      key_insights = extracted["key_insights"]

      has_feedback = feedback_text.present? || key_insights.present?

      {
        has_feedback: has_feedback,
        feedback_text: feedback_text,
        key_insights: key_insights,
        feedback_type: determine_feedback_type
      }
    end

    # Determines the feedback type based on email type
    #
    # @return [String]
    def determine_feedback_type
      case synced_email.email_type
      when "rejection" then "rejection"
      when "offer" then "offer"
      when "round_feedback" then "general"
      else "general"
      end
    end

    # Creates company feedback record
    #
    # @param data [Hash]
    # @return [CompanyFeedback, nil]
    def create_feedback_record(data)
      # Don't duplicate if feedback exists for the application from the same source
      return nil if application.company_feedback.present? && data[:feedback_type] != "general"

      feedback_text = build_feedback_text(data)
      return nil if feedback_text.blank?

      CompanyFeedback.create!(
        interview_application: application,
        source_email_id: synced_email.id,
        feedback_type: data[:feedback_type],
        feedback_text: feedback_text,
        received_at: synced_email.received_at || Time.current
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("CompanyFeedbackProcessor: Failed to create feedback: #{e.message}")
      nil
    end

    # Builds feedback text from extracted data
    #
    # @param data [Hash]
    # @return [String]
    def build_feedback_text(data)
      parts = []

      if data[:feedback_text].present?
        parts << data[:feedback_text]
      end

      if data[:key_insights].present? && data[:feedback_text].blank?
        parts << "Key Insights:\n#{data[:key_insights]}"
      end

      parts.join("\n\n").strip
    end
  end
end
