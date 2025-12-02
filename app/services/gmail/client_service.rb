# frozen_string_literal: true

# Service for managing Gmail API client connections
#
# @example
#   service = Gmail::ClientService.new(connected_account)
#   client = service.client
#
class Gmail::ClientService
  # @return [ConnectedAccount] The connected account
  attr_reader :connected_account

  # Initialize the client service
  #
  # @param connected_account [ConnectedAccount] The connected account with OAuth tokens
  def initialize(connected_account)
    @connected_account = connected_account
  end

  # Returns a configured Gmail API client
  #
  # @return [Google::Apis::GmailV1::GmailService]
  # @raise [Gmail::TokenExpiredError] If the token is expired and can't be refreshed
  def client
    refresh_token_if_needed!

    @client ||= begin
      service = Google::Apis::GmailV1::GmailService.new
      service.authorization = authorization
      service
    end
  end

  # Returns the user's email address (me)
  #
  # @return [String]
  def user_id
    "me"
  end

  private

  # Creates an authorization object for the API
  #
  # @return [Signet::OAuth2::Client]
  def authorization
    Signet::OAuth2::Client.new(
      client_id: Rails.application.credentials.dig(:google, :client_id),
      client_secret: Rails.application.credentials.dig(:google, :client_secret),
      token_credential_uri: "https://oauth2.googleapis.com/token",
      access_token: connected_account.access_token,
      refresh_token: connected_account.refresh_token,
      expires_at: connected_account.expires_at
    )
  end

  # Refreshes the token if it's expired or expiring soon
  #
  # @return [void]
  # @raise [Gmail::TokenExpiredError] If the token can't be refreshed
  def refresh_token_if_needed!
    return unless connected_account.token_expiring_soon?
    return unless connected_account.refreshable?

    refresh_token!
  end

  # Refreshes the access token using the refresh token
  #
  # @return [void]
  # @raise [Gmail::TokenExpiredError] If the refresh fails
  def refresh_token!
    auth = authorization
    auth.refresh!

    connected_account.update!(
      access_token: auth.access_token,
      expires_at: Time.at(auth.expires_at)
    )

    # Reset the client to use new tokens
    @client = nil
  rescue Signet::AuthorizationError => e
    Rails.logger.error "Gmail token refresh failed: #{e.message}"
    raise Gmail::TokenExpiredError, "Failed to refresh Gmail token. Please reconnect your account."
  end
end

# Custom error for expired tokens
class Gmail::TokenExpiredError < StandardError; end

