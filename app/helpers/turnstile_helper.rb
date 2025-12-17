# frozen_string_literal: true

# Helper for Cloudflare Turnstile integration
module TurnstileHelper
  # Returns the Turnstile site key
  #
  # @return [String, nil]
  def turnstile_site_key
    CloudflareTurnstileService.site_key
  end

  # Checks if Turnstile is configured
  #
  # @return [Boolean]
  def turnstile_configured?
    turnstile_site_key.present? && Setting.turnstile_enabled?
  end
end
