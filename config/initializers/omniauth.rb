# frozen_string_literal: true

# Load custom OmniAuth strategies before configuration
require_relative "../../lib/omniauth/strategies/techwright"

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

  # TechWright SSO for developer portal authentication
  # Site URL can be configured via credentials (e.g., http://localhost:3003 for development)
  # For devcontainer setups, use separate URLs:
  #   - site: browser-accessible URL (localhost:3003)
  #   - token_site: server-accessible URL (host.docker.internal:3003)
  techwright_site = Rails.application.credentials.dig(:techwright, :site) || "https://techwright.io"
  techwright_token_site = Rails.application.credentials.dig(:techwright, :token_site)

  provider :techwright,
    Rails.application.credentials.dig(:techwright, :client_id),
    Rails.application.credentials.dig(:techwright, :client_secret),
    scope: "openid email profile",
    token_site: techwright_token_site,
    client_options: {
      site: techwright_site,
      token_site: techwright_token_site,
      authorize_url: "/oauth/authorize",
      token_url: "/oauth/token"
    }
end

# Handle OAuth failures gracefully
# Route TechWright failures to the developer sessions controller
OmniAuth.config.on_failure = proc do |env|
  strategy = env["omniauth.error.strategy"]
  if strategy&.name == "techwright"
    Internal::Developer::SessionsController.action(:failure).call(env)
  else
    OauthCallbacksController.action(:failure).call(env)
  end
end

# Only allow POST for OAuth requests (CSRF protection)
# GET requests are vulnerable to CSRF attacks
OmniAuth.config.allowed_request_methods = [ :post ]
