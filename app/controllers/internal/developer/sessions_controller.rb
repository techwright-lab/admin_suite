# frozen_string_literal: true

module Internal
  module Developer
    # Controller for developer portal authentication via TechWright SSO
    #
    # Handles login, OAuth callbacks, and logout for the admin portal.
    # Developers authenticate separately from regular users.
    class SessionsController < ApplicationController
      # Skip regular user authentication - developers use TechWright SSO
      allow_unauthenticated_access
      # Skip CSRF for OAuth callbacks (they come from external provider)
      skip_before_action :verify_authenticity_token, only: [ :create, :failure ]

      layout "developer_login"

      # GET /internal/developer/login
      #
      # Shows the developer login page with TechWright SSO button
      def new
        redirect_to internal_developer_root_path if developer_authenticated?
      end

      # GET /internal
      #
      # Redirects to developer portal if signed in, otherwise to login
      def redirect_root
        if developer_authenticated?
          redirect_to internal_developer_root_path
        else
          redirect_to internal_developer_login_path
        end
      end

      # GET /auth/failure (for TechWright)
      #
      # Handles TechWright OAuth authentication failures
      def failure
        error_message = params[:message] || "unknown error"
        Rails.logger.warn "TechWright OAuth failure: #{error_message}"

        redirect_to internal_developer_login_path,
          alert: "Authentication failed: #{error_message.humanize}. Please try again."
      end

      # GET/POST /auth/techwright/callback
      #
      # Handles TechWright OAuth callback, creates or updates developer record
      def create
        auth = request.env["omniauth.auth"]

        if auth.nil?
          redirect_to internal_developer_login_path, alert: "Authentication failed. Please try again."
          return
        end

        developer = ::Developer.find_or_create_from_omniauth(auth)

        unless developer.enabled?
          redirect_to internal_developer_login_path,
            alert: "Your developer access has been disabled."
          return
        end

        developer.record_login!(ip_address: request.remote_ip)
        session[:developer_id] = developer.id

        redirect_to internal_developer_root_path,
          notice: "Welcome, #{developer.name || developer.email}!"
      end

      # DELETE /internal/developer/logout
      #
      # Signs out the developer and optionally revokes the OAuth token
      def destroy
        revoke_token if current_developer&.access_token.present?
        session.delete(:developer_id)

        redirect_to internal_developer_login_path,
          notice: "Signed out successfully.", status: :see_other
      end

      private

      # Revokes the OAuth token at TechWright
      #
      # @return [void]
      def revoke_token
        return unless current_developer&.access_token.present?

        # Use token_site for server-side requests (supports devcontainer setups)
        site = Rails.application.credentials.dig(:techwright, :token_site) ||
               Rails.application.credentials.dig(:techwright, :site) ||
               "https://techwright.io"
        uri = URI("#{site}/oauth/revoke")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"

        request = Net::HTTP::Post.new(uri)
        request.set_form_data(
          token: current_developer.access_token,
          client_id: Rails.application.credentials.dig(:techwright, :client_id),
          client_secret: Rails.application.credentials.dig(:techwright, :client_secret)
        )

        http.request(request)
      rescue StandardError => e
        Rails.logger.error("TechWright token revocation failed: #{e.message}")
      end

      # Checks if a developer is currently authenticated
      #
      # @return [Boolean]
      def developer_authenticated?
        current_developer.present?
      end

      # Returns the currently authenticated developer
      #
      # @return [Developer, nil]
      def current_developer
        @current_developer ||= ::Developer.enabled.find_by(id: session[:developer_id])
      end
    end
  end
end
