# frozen_string_literal: true

# Session Cookie Configuration
#
# Security settings:
# - secure: Only send over HTTPS in production
# - httponly: Prevent JavaScript access (XSS protection)
# - same_site: Lax prevents CSRF on most cross-site requests
# - expire_after: Session expires after 2 weeks of inactivity
#
Rails.application.config.session_store :cookie_store,
  key: "_gleania_session",
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax,
  expire_after: 2.weeks
