# frozen_string_literal: true

# Controller for handling OAuth callbacks from external providers
class OauthCallbacksController < ApplicationController
  # Allow unauthenticated access for sign-in/sign-up flow
  allow_unauthenticated_access only: [ :create, :failure ]
  # Skip CSRF for OAuth callbacks (they come from external providers)
  skip_before_action :verify_authenticity_token, only: [ :create ]

  # GET/POST /auth/:provider/callback
  # Handle successful OAuth authentication
  def create
    auth = request.env["omniauth.auth"]

    if auth.nil?
      handle_missing_auth
      return
    end

    begin
      if authenticated?
        # User is already signed in - connect OAuth account
        handle_account_connection(auth)
      else
        # User is not signed in - sign in or sign up with OAuth
        handle_authentication(auth)
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "OAuth error: #{e.message}"
      handle_error(e.record.errors.full_messages.join(", "))
    rescue StandardError => e
      Rails.logger.error "OAuth error: #{e.class} - #{e.message}"
      handle_error("An error occurred. Please try again.")
    end
  end

  # GET /auth/failure
  # Handle OAuth authentication failures
  def failure
    error_message = params[:message] || "unknown error"
    error_strategy = params[:strategy] || "unknown"

    Rails.logger.warn "OAuth failure for #{error_strategy}: #{error_message}"

    redirect_path = authenticated? ? settings_path(tab: "integrations") : new_session_path
    redirect_to redirect_path,
      alert: "Authentication failed: #{error_message.humanize}. Please try again."
  end

  private

  # Handles the case when auth data is missing
  # @return [void]
  def handle_missing_auth
    redirect_path = authenticated? ? settings_path(tab: "integrations") : new_session_path
    redirect_to redirect_path, alert: "Authentication failed. Please try again."
  end

  # Handles connecting an OAuth account to an existing logged-in user
  # @param auth [OmniAuth::AuthHash] The OAuth authentication data
  # @return [void]
  def handle_account_connection(auth)
    @connected_account = ConnectedAccount.from_oauth(Current.user, auth)

    redirect_to settings_path(tab: "integrations"),
      notice: "Successfully connected your #{provider_name} account!"
  end

  # Handles sign-in or sign-up via OAuth
  # @param auth [OmniAuth::AuthHash] The OAuth authentication data
  # @return [void]
  def handle_authentication(auth)
    user = OauthAuthenticationService.new(auth).run
    start_new_session_for(user)

    redirect_to after_authentication_url,
      notice: "Welcome! Successfully signed in with #{provider_name}."
  end

  # Handles errors during OAuth flow
  # @param message [String] The error message
  # @return [void]
  def handle_error(message)
    redirect_path = authenticated? ? settings_path(tab: "integrations") : new_session_path
    redirect_to redirect_path, alert: message
  end

  # Returns a human-readable name for the provider
  # @return [String]
  def provider_name
    case params[:provider]
    when "google_oauth2"
      "Google"
    else
      params[:provider].to_s.titleize
    end
  end
end
