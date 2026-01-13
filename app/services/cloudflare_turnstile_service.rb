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
  def self.verify(token, remote_ip = nil)
    # If Turnstile is not fully configured, allow the request through
    # (this handles dev environments without keys)
    return true unless fully_configured?

    if token.blank?
      Rails.logger.warn "Turnstile verification failed: token is blank"
      return false
    end

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
      error_codes = result["error-codes"]&.join(", ") || "unknown"
      Rails.logger.warn "Turnstile verification failed: #{error_codes} (#{result.inspect})"
      return false
    end

    true
  rescue JSON::ParserError, HTTParty::Error, Net::TimeoutError => e
    Rails.logger.error "Turnstile verification error: #{e.message}"
    # On network errors, fail open to avoid blocking legitimate users
    # in case of Cloudflare issues
    Rails.env.production? ? false : true
  end

  # Returns the site key for client-side use
  #
  # @return [String, nil] The Turnstile site key
  def self.site_key
    Rails.application.credentials.dig(:cloudflare, :turnstile_site_key) ||
      ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
  end

  # Returns the secret key for server-side verification
  #
  # @return [String, nil] The Turnstile secret key
  def self.secret_key
    Rails.application.credentials.dig(:cloudflare, :turnstile_secret_key) ||
      ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
  end

  # Checks if Turnstile is fully configured (both keys present)
  #
  # @return [Boolean] True if both site and secret keys are present
  def self.fully_configured?
    site_key.present? && secret_key.present?
  end
end
