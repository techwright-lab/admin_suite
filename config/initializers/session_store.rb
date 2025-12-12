# frozen_string_literal: true

# Configure session store (simplified)
Rails.application.config.session_store :cookie_store,
  key: "_gleania_session",
  secure: Rails.env.production?,  # Only use secure cookies in production
  httponly: true,  # Prevent JavaScript access to session cookie
  same_site: :lax  # Allow cross-site requests
