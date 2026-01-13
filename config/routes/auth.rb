# frozen_string_literal: true

# Authentication routes
#
# User authentication, registration, password reset, and email verification

# Session management (login/logout)
get "login", to: "sessions#new", as: :new_session
post "login", to: "sessions#create", as: :session
delete "logout", to: "sessions#destroy", as: :logout

# Registration
get "signup", to: "registrations#new", as: :new_registration
post "signup", to: "registrations#create", as: :registrations

# Password reset
resources :passwords, param: :token

# Email verification
get "email_verification/new", to: "email_verifications#new", as: :new_email_verification
post "email_verification", to: "email_verifications#create", as: :resend_email_verification
get "email_verification/:token", to: "email_verifications#show", as: :email_verification

# OAuth callbacks
get "/auth/:provider/callback", to: "oauth_callbacks#create", as: :oauth_callback
post "/auth/:provider/callback", to: "oauth_callbacks#create"
get "/auth/failure", to: "oauth_callbacks#failure", as: :oauth_failure
