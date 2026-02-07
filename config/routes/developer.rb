# frozen_string_literal: true

# Developer (TechWright SSO) authentication and AdminSuite at /internal/developer
#
# Login and logout are defined first so they take precedence over the engine mount.
# AdminSuite (engine) then handles /internal/developer, /internal/developer/ops, etc.

# =================================================================
# Developer Authentication (TechWright SSO)
# =================================================================
get "/internal/developer/login", to: "internal/developer/sessions#new", as: :internal_developer_login
delete "/internal/developer/logout", to: "internal/developer/sessions#destroy", as: :internal_developer_logout

# TechWright OAuth callback
get "/auth/techwright/callback", to: "internal/developer/sessions#create"
post "/auth/techwright/callback", to: "internal/developer/sessions#create"

# =================================================================
# AdminSuite engine (mounted in config/routes.rb after this file so login/logout take precedence)
# =================================================================
