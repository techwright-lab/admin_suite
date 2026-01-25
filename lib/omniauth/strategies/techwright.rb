# frozen_string_literal: true

require "omniauth-oauth2"

module OmniAuth
  module Strategies
    # TechWright OAuth2 strategy for OmniAuth
    #
    # Used for authenticating developers to the internal admin portal.
    # This is separate from regular user authentication.
    #
    # Supports separate URLs for browser (authorize) and server (token) requests,
    # which is needed for devcontainer setups where localhost from the container
    # doesn't reach the host machine.
    #
    # @example Configuration
    #   provider :techwright,
    #     Rails.application.credentials.dig(:techwright, :client_id),
    #     Rails.application.credentials.dig(:techwright, :client_secret),
    #     scope: "openid email profile",
    #     client_options: {
    #       site: "http://localhost:3003",
    #       token_site: "http://host.docker.internal:3003"
    #     }
    #
    class Techwright < OmniAuth::Strategies::OAuth2
      option :name, "techwright"

      # Default to production URL, can be overridden via credentials or provider options
      option :client_options, {
        site: "https://techwright.io",
        authorize_url: "/oauth/authorize",
        token_url: "/oauth/token"
      }

      # Optional separate site for server-side requests (token exchange, userinfo)
      # Used in devcontainer setups where localhost doesn't work from inside container
      option :token_site, nil

      # Returns the unique identifier for the user
      #
      # @return [String] The user's TechWright ID
      uid { raw_info["sub"] }

      # Returns user information from the OAuth response
      #
      # @return [Hash] User info including email, name, picture, and verification status
      info do
        {
          email: raw_info["email"],
          name: raw_info["name"],
          image: raw_info["picture"],
          email_verified: raw_info["email_verified"]
        }
      end

      # Returns additional data from the OAuth response
      #
      # @return [Hash] Extra data including the raw userinfo response
      extra do
        { raw_info: raw_info }
      end

      # Override client to use token_site for server-side requests
      #
      # @return [OAuth2::Client]
      def client
        @client ||= begin
          # Use token_site if provided, otherwise fall back to site
          server_site = options.token_site || options.client_options[:token_site] || options.client_options[:site]

          ::OAuth2::Client.new(
            options.client_id,
            options.client_secret,
            deep_symbolize(options.client_options.merge(site: server_site))
          )
        end
      end

      # Fetches user information from the TechWright userinfo endpoint
      #
      # @return [Hash] The parsed userinfo response
      def raw_info
        @raw_info ||= access_token.get("/oauth/userinfo").parsed
      end

      # Returns the callback URL for OAuth redirects
      #
      # @return [String] The full callback URL
      def callback_url
        full_host + callback_path
      end

      # Build the authorize URL using the browser-accessible site
      #
      # @param params [Hash] Additional parameters
      # @return [String] The authorization URL
      def authorize_url(params = {})
        # Use the original site (browser-accessible) for authorize URL
        browser_site = options.client_options[:site]
        authorize_path = options.client_options[:authorize_url] || "/oauth/authorize"

        uri = URI.parse(browser_site)
        uri.path = authorize_path
        uri.query = URI.encode_www_form(params) if params.any?
        uri.to_s
      end

      # Override request_phase to use browser-accessible site for redirect
      def request_phase
        browser_site = options.client_options[:site]
        authorize_path = options.client_options[:authorize_url] || "/oauth/authorize"

        # Build authorize params
        authorize_params = {
          client_id: options.client_id,
          redirect_uri: callback_url,
          response_type: "code",
          scope: options.scope
        }
        authorize_params[:state] = session["omniauth.state"] = SecureRandom.hex(24)

        redirect URI.parse(browser_site).merge(authorize_path + "?" + URI.encode_www_form(authorize_params)).to_s
      end
    end
  end
end
