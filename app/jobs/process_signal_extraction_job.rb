# frozen_string_literal: true

# Background job for extracting actionable signals from synced emails
#
# Runs AI extraction on synced emails to extract company info, recruiter details,
# job information, and suggested actions. Also triggers automated email processors
# to create interview rounds, update statuses, and capture feedback.
#
# @example
#   ProcessSignalExtractionJob.perform_later(synced_email.id)
#
class ProcessSignalExtractionJob < ApplicationJob
  queue_as :default

  # Retry on transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry on permanent failures
  discard_on ActiveRecord::RecordNotFound

  # Process the email with AI signal extraction
  #
  # @param synced_email_id [Integer] The synced email ID to process
  # @return [void]
  def perform(synced_email_id)
    synced_email = SyncedEmail.find(synced_email_id)

    # Skip if already extracted
    return if synced_email.extraction_completed?

    # Skip if extraction was skipped (not suitable for extraction)
    return if synced_email.extraction_status == "skipped"

    Rails.logger.info("Processing signal extraction for email #{synced_email_id}")

    # Run AI extraction
    service = Signals::ExtractionService.new(synced_email)
    result = service.extract

    if result[:success]
      Rails.logger.info("Successfully extracted signals for email #{synced_email_id}")

      # Log key extracted data
      synced_email.reload
      if synced_email.signal_company_name.present?
        Rails.logger.info("  Company: #{synced_email.signal_company_name}")
      end

      # Process automated actions based on email type
      process_email_actions(synced_email)
    elsif result[:skipped]
      Rails.logger.info("Skipped signal extraction for email #{synced_email_id}: #{result[:reason]}")
    else
      Rails.logger.warn("Failed to extract signals for email #{synced_email_id}: #{result[:error]}")
    end
  end

  private

  # Processes automated actions based on email type
  #
  # @param synced_email [SyncedEmail]
  def process_email_actions(synced_email)
    return unless synced_email.matched?

    Rails.logger.info("Processing automated actions for email #{synced_email.id} (type: #{synced_email.email_type})")

    case synced_email.email_type
    when "scheduling", "interview_invite", "interview_reminder"
      process_interview_round(synced_email)
    when "round_feedback"
      process_round_feedback(synced_email)
    when "rejection", "offer"
      process_status_change(synced_email)
    end

    # Always try to capture feedback if available
    process_company_feedback(synced_email) if synced_email.matched?
  end

  # Processes interview round creation
  #
  # @param synced_email [SyncedEmail]
  def process_interview_round(synced_email)
    processor = Signals::InterviewRoundProcessor.new(synced_email)
    result = processor.process

    if result[:success]
      Rails.logger.info("Created/updated interview round from email #{synced_email.id}: #{result[:action]}")
    elsif result[:skipped]
      Rails.logger.info("Skipped interview round processing: #{result[:reason]}")
    else
      Rails.logger.warn("Failed to process interview round: #{result[:error]}")
    end
  end

  # Processes round feedback
  #
  # @param synced_email [SyncedEmail]
  def process_round_feedback(synced_email)
    processor = Signals::RoundFeedbackProcessor.new(synced_email)
    result = processor.process

    if result[:success]
      Rails.logger.info("Processed round feedback from email #{synced_email.id}: #{result[:action]}")
    elsif result[:skipped]
      Rails.logger.info("Skipped round feedback processing: #{result[:reason]}")
    else
      Rails.logger.warn("Failed to process round feedback: #{result[:error]}")
    end
  end

  # Processes application status change
  #
  # @param synced_email [SyncedEmail]
  def process_status_change(synced_email)
    processor = Signals::ApplicationStatusProcessor.new(synced_email)
    result = processor.process

    if result[:success]
      Rails.logger.info("Processed status change from email #{synced_email.id}: #{result[:action]}")
    elsif result[:skipped]
      Rails.logger.info("Skipped status change processing: #{result[:reason]}")
    else
      Rails.logger.warn("Failed to process status change: #{result[:error]}")
    end
  end

  # Processes company feedback capture
  #
  # @param synced_email [SyncedEmail]
  def process_company_feedback(synced_email)
    processor = Signals::CompanyFeedbackProcessor.new(synced_email)
    result = processor.process

    if result[:success]
      Rails.logger.info("Captured company feedback from email #{synced_email.id}")
    elsif result[:skipped]
      # Don't log skipped feedback - this is common
    else
      Rails.logger.warn("Failed to capture company feedback: #{result[:error]}")
    end
  end
end
