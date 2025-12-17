# frozen_string_literal: true

# OmniAuth configuration for OAuth integrations
Rails.application.config.middleware.use OmniAuth::Builder do
  # Google OAuth2 for Gmail integration
  provider :google_oauth2,
    Rails.application.credentials.dig(:google, :client_id),
    Rails.application.credentials.dig(:google, :client_secret),
    {
      name: "google_oauth2",
      scope: [
        "email",
        "profile",
        "https://www.googleapis.com/auth/gmail.readonly"
      ].join(" "),
      prompt: "consent",
      access_type: "offline",
      include_granted_scopes: true
    }
end

# Handle OAuth failures gracefully
OmniAuth.config.on_failure = proc do |env|
  OauthCallbacksController.action(:failure).call(env)
end

# Allow both POST and GET for OAuth (POST for CSRF protection, GET for compatibility)
OmniAuth.config.allowed_request_methods = [ :post, :get ]
