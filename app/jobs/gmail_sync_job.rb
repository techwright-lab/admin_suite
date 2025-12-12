# frozen_string_literal: true

# Background job for syncing Gmail emails
# This job fetches interview-related emails from the user's Gmail account
class GmailSyncJob < ApplicationJob
  queue_as :default

  # Number of times to retry on transient failures
  retry_on Gmail::Errors::TokenExpiredError, wait: :polynomially_longer, attempts: 3
  retry_on Google::Apis::TransmissionError, wait: :polynomially_longer, attempts: 3

  # Don't retry on auth errors - user needs to reconnect
  # Use a block to mark account as needing reauth when discarded
  discard_on Google::Apis::AuthorizationError do |job, error|
    handle_auth_failure(job, error)
  end

  # Performs the Gmail sync for a user
  #
  # @param user [User] The user to sync emails for
  # @param connected_account [ConnectedAccount, nil] Specific account to sync (optional)
  def perform(user, connected_account: nil)
    account = connected_account || user.google_account

    unless account
      Rails.logger.info "No Google account connected for user #{user.id}"
      return
    end

    unless account.sync_enabled?
      Rails.logger.info "Gmail sync disabled for user #{user.id}"
      return
    end

    # Store account for potential error handling
    @account = account

    service = Gmail::SyncService.new(account)
    result = service.run

    if result[:success]
      Rails.logger.info "Gmail sync completed for user #{user.id}: #{result[:emails_found]} emails found"
    else
      Rails.logger.warn "Gmail sync failed for user #{user.id}: #{result[:error]}"

      # If reauth is needed, mark account and notify user
      if result[:needs_reauth]
        mark_needs_reauth_and_notify(account, result[:error])
      end
    end

    result
  end

  private

  # Marks the account as needing reauthorization and sends notification
  #
  # @param account [ConnectedAccount] The connected account
  # @param error_message [String] The error message
  def mark_needs_reauth_and_notify(account, error_message)
    account.mark_needs_reauth!(error_message)
    ConnectedAccountMailer.reauth_required(account).deliver_later
    Rails.logger.info "Marked account #{account.id} as needing reauth and sent notification"
  end

  # Class method to handle auth failures from discard_on callback
  #
  # @param job [GmailSyncJob] The job instance
  # @param error [Exception] The error that caused the discard
  def self.handle_auth_failure(job, error)
    # Extract the account from job arguments
    user = job.arguments.first
    account = job.arguments.second&.fetch(:connected_account, nil) || user&.google_account

    return unless account

    Rails.logger.error "Gmail authorization failed for account #{account.id}: #{error.message}"
    account.mark_needs_reauth!(error.message)
    ConnectedAccountMailer.reauth_required(account).deliver_later
  end
end
