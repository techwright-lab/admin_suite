# frozen_string_literal: true

# Background job for syncing Gmail emails for all users with connected accounts
# This job is scheduled to run periodically via Solid Queue recurring jobs
class GmailSyncAllUsersJob < ApplicationJob
  queue_as :default

  # Performs Gmail sync for all users with connected Google accounts
  # Only syncs accounts that have sync enabled and don't need reauthorization
  # Accounts with expired access tokens will still be processed (refresh will be attempted)
  def perform
    accounts_to_sync = ConnectedAccount.google.sync_enabled.ready_for_sync

    Rails.logger.info "Starting Gmail sync for #{accounts_to_sync.count} accounts"

    accounts_to_sync.find_each do |account|
      # Queue individual sync job for each account
      # This allows individual syncs to fail without affecting others
      GmailSyncJob.perform_later(account.user, connected_account: account)
    rescue StandardError => e
      Rails.logger.error "Failed to queue sync for account #{account.id}: #{e.message}"
    end

    Rails.logger.info "Gmail sync jobs queued for #{accounts_to_sync.count} accounts"
  end
end
