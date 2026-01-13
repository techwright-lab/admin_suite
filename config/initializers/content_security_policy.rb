# frozen_string_literal: true

# Content Security Policy Configuration
#
# Protects against XSS and other injection attacks by specifying which
# resources the browser is allowed to load.
#
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    # Default: only allow resources from same origin
    policy.default_src :self

    # Fonts: self, data URIs (for inline fonts)
    policy.font_src :self, :data,
                     "https://fonts.googleapis.com",
                     "https://fonts.gstatic.com"

    # Images: self, data URIs, HTTPS sources (for external logos, avatars)
    # blob: is needed for image previews/uploads
    policy.img_src :self, :data, :https, :blob

    # Objects (Flash, etc.): block entirely
    policy.object_src :none

    # Scripts: self + nonce for inline scripts
    # jsdelivr for EasyMDE editor in developer portal
    # challenges.cloudflare.com for Turnstile captcha
    policy.script_src :self,
                      "https://cdn.jsdelivr.net",
                      "https://challenges.cloudflare.com"

    # Styles: self + nonce for inline styles
    # jsdelivr for EasyMDE styles
    # 'unsafe-inline' needed for Tailwind's dynamic styles - consider removing if possible
    policy.style_src :self,
                     :unsafe_inline,
                     "https://cdn.jsdelivr.net",
                     "https://fonts.googleapis.com"

    # Frames: allow Cloudflare Turnstile iframe
    policy.frame_src :self,
                     "https://challenges.cloudflare.com"

    # Connect: self for fetch/XHR, ActionCable websockets
    # Sentry for error reporting
    # LemonSqueezy for billing
    policy.connect_src :self, :wss, :https, # WebSocket connections
                       "https://*.ingest.sentry.io",
                       "https://*.lemonsqueezy.com",
                       "https://ga.jspm.io"

    # Form submissions: only to self
    policy.form_action :self,
                       "https://accounts.google.com"  # OAuth

    # Frame ancestors: prevent clickjacking - only allow self
    policy.frame_ancestors :self

    # Base URI: restrict <base> tag
    policy.base_uri :self

    # Manifest: allow PWA manifest
    policy.manifest_src :self

    # Report violations to your error tracking (optional)
    # Uncomment and configure if you want violation reports
    # policy.report_uri "/csp-violation-report"
  end

  # Generate nonces for inline scripts and styles
  # This allows specific inline scripts/styles while blocking others
  config.content_security_policy_nonce_generator = ->(request) {
    # Use request-specific nonce (more secure than session-based)
    SecureRandom.base64(16)
  }

  # Apply nonces to script-src and style-src
  config.content_security_policy_nonce_directives = %w[script-src]

  # Report-Only mode: Set to true to test CSP without blocking
  # Recommended: Start with true, monitor for issues, then set to false
  config.content_security_policy_report_only = Rails.env.development?
end
