# frozen_string_literal: true

# Helper for Cloudflare Turnstile integration
module TurnstileHelper
  # Returns the Turnstile site key
  #
  # @return [String, nil]
  def turnstile_site_key
    CloudflareTurnstileService.site_key
  end

  # Checks if Turnstile is configured and enabled
  # Only returns true if BOTH site key and secret key are present
  # and the setting is enabled. This ensures the widget is only shown
  # when verification can actually succeed.
  #
  # @return [Boolean]
  def turnstile_configured?
    Setting.turnstile_enabled? && CloudflareTurnstileService.fully_configured?
  end
end
