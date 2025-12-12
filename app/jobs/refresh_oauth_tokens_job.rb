# frozen_string_literal: true

# Background job for proactively refreshing OAuth tokens before they expire
# This helps prevent sync failures due to expired tokens
class RefreshOauthTokensJob < ApplicationJob
  queue_as :default

  # Refreshes OAuth tokens that are about to expire
  # This job runs periodically to ensure tokens are fresh before sync jobs need them
  def perform
    # Find accounts with tokens expiring within the next hour
    # that haven't been marked as needing reauth
    accounts_to_refresh = ConnectedAccount.google
                                          .sync_enabled
                                          .ready_for_sync
                                          .expiring_soon

    Rails.logger.info "Starting proactive token refresh for #{accounts_to_refresh.count} accounts"

    refreshed_count = 0
    failed_count = 0

    accounts_to_refresh.find_each do |account|
      refresh_account_token(account)
      refreshed_count += 1
    rescue Signet::AuthorizationError => e
      handle_refresh_failure(account, e)
      failed_count += 1
    rescue StandardError => e
      Rails.logger.error "Unexpected error refreshing token for account #{account.id}: #{e.message}"
      failed_count += 1
    end

    Rails.logger.info "Token refresh completed: #{refreshed_count} refreshed, #{failed_count} failed"
  end

  private

  # Refreshes the token for a single account
  #
  # @param account [ConnectedAccount] The account to refresh
  def refresh_account_token(account)
    return unless account.refreshable?

    client_service = Gmail::ClientService.new(account)
    client_service.send(:refresh_token!)

    Rails.logger.debug "Successfully refreshed token for account #{account.id}"
  end

  # Handles a failed token refresh
  #
  # @param account [ConnectedAccount] The account that failed to refresh
  # @param error [Signet::AuthorizationError] The error
  def handle_refresh_failure(account, error)
    Rails.logger.warn "Token refresh failed for account #{account.id}: #{error.message}"

    # Mark the account as needing reauthorization
    account.mark_needs_reauth!(error.message)

    # Notify the user
    ConnectedAccountMailer.reauth_required(account).deliver_later
  end
end
