# frozen_string_literal: true

require "httparty"

# Service for verifying Cloudflare Turnstile tokens
class CloudflareTurnstileService
  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  class VerificationError < StandardError; end

  # Verifies a Turnstile token
  #
  # @param token [String] The Turnstile token from the client
  # @param remote_ip [String] The user's IP address
  # @return [Boolean] True if verification succeeds
  # @raise [VerificationError] If verification fails
  def self.verify(token, remote_ip = nil)
    return false if token.blank?

    secret_key = Rails.application.credentials.dig(:cloudflare, :turnstile_secret_key) ||
                 ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]

    return false if secret_key.blank?

    response = HTTParty.post(
      VERIFY_URL,
      body: {
        secret: secret_key,
        response: token,
        remoteip: remote_ip
      },
      timeout: 5
    )

    result = JSON.parse(response.body)

    unless result["success"]
      Rails.logger.warn "Turnstile verification failed: #{result.inspect}"
      return false
    end

    true
  rescue JSON::ParserError, HTTParty::Error, Net::TimeoutError => e
    Rails.logger.error "Turnstile verification error: #{e.message}"
    false
  end

  # Returns the site key for client-side use
  #
  # @return [String, nil] The Turnstile site key
  def self.site_key
    Rails.application.credentials.dig(:cloudflare, :turnstile_site_key) ||
      ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
  end
end
