# frozen_string_literal: true

# Main Routes Configuration
#
# Routes are organized into separate files under config/routes/:
#   - admin.rb      - Admin panel routes (/admin/*)
#   - public.rb     - Public pages (blog, contact, legal)
#   - auth.rb       - Authentication routes (login, signup, OAuth)
#   - assistant.rb  - AI Assistant routes
#   - application.rb - Main app routes for authenticated users
#
# Common patterns are extracted into routing concerns below.

Rails.application.routes.draw do
  # =================================================================
  # Routing Concerns
  # =================================================================
  # Reusable route patterns to DRY up common resource actions

  # Toggle enable/disable on resources (e.g., companies, job_roles)
  concern :toggleable do
      member do
        post :disable
        post :enable
      end
    end

  # Merge resources (e.g., companies, skill_tags)
  concern :mergeable do
      member do
        get :merge
        post :merge_into
      end
    end

  # Export resource data
  concern :exportable do
    member do
      get :export
    end
  end

  # Autocomplete search for lookups
  concern :autocompletable do
    collection do
      get :autocomplete
    end
  end

  # =================================================================
  # Engine Mounts (Internal Tools)
  # =================================================================
  namespace :internal do
    mount MissionControl::Jobs::Engine, at: "/jobs"
    mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
  end

  # =================================================================
  # Draw Routes from Separate Files
  # =================================================================
  draw :developer  # Admin framework at /internal/developer
  draw :public
  draw :auth
  draw :webhooks
  draw :assistant
  draw :application

  # =================================================================
  # Root & Health Check
  # =================================================================
  get "up" => "rails/health#show", as: :rails_health_check
  get "dashboard", to: "dashboard#index", as: :dashboard
  root "public/home#index"
end
