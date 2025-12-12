# frozen_string_literal: true

# Background job for processing opportunity emails with AI extraction
#
# Runs AI extraction on opportunities to extract job details from recruiter emails.
# Called after a recruiter outreach email is detected and an opportunity is created.
#
# @example
#   ProcessOpportunityEmailJob.perform_later(opportunity.id)
#
class ProcessOpportunityEmailJob < ApplicationJob
  queue_as :default

  # Retry on transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry on permanent failures
  discard_on ActiveRecord::RecordNotFound

  # Process the opportunity with AI extraction
  #
  # @param opportunity_id [Integer] The opportunity ID to process
  # @return [void]
  def perform(opportunity_id)
    opportunity = Opportunity.find(opportunity_id)

    # Skip if already processed (has extracted data)
    return if opportunity.extracted_data["extracted_at"].present?

    # Skip if no email attached
    return unless opportunity.synced_email.present?

    Rails.logger.info("Processing opportunity #{opportunity_id} for AI extraction")

    # Run AI extraction
    service = Opportunities::ExtractionService.new(opportunity)
    result = service.extract

    if result[:success]
      Rails.logger.info("Successfully extracted data for opportunity #{opportunity_id}")

      # If we found a job URL, we could optionally trigger job listing scraping
      # For now, we just store the extracted data
      if opportunity.reload.job_url.present?
        Rails.logger.info("Opportunity #{opportunity_id} has job URL: #{opportunity.job_url}")
      end
    else
      Rails.logger.warn("Failed to extract data for opportunity #{opportunity_id}: #{result[:error]}")
    end
  end
end
