# frozen_string_literal: true

# Background job for syncing Gmail emails
# This job fetches interview-related emails from the user's Gmail account
class GmailSyncJob < ApplicationJob
  queue_as :default

  # Number of times to retry on transient failures
  retry_on Gmail::TokenExpiredError, wait: :polynomially_longer, attempts: 3
  retry_on Google::Apis::TransmissionError, wait: :polynomially_longer, attempts: 3

  # Don't retry on auth errors - user needs to reconnect
  discard_on Google::Apis::AuthorizationError

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

    service = Gmail::SyncService.new(account)
    result = service.run

    if result[:success]
      Rails.logger.info "Gmail sync completed for user #{user.id}: #{result[:emails_found]} emails found"
    else
      Rails.logger.warn "Gmail sync failed for user #{user.id}: #{result[:error]}"

      # If reauth is needed, we should notify the user
      if result[:needs_reauth]
        # TODO: Send notification to user about reconnecting their account
        account.update(sync_enabled: false)
      end
    end

    result
  end
end

