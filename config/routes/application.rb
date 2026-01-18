# frozen_string_literal: true

# Main application routes
#
# Core application features for authenticated users:
# - Interview applications and rounds
# - Profile and settings
# - Inbox, opportunities, saved jobs
# - Resumes and skills

# =================================================================
# Interview Applications
# =================================================================
resources :interview_applications, path: "applications" do
  resource :prep, only: [] do
    post :refresh, to: "interview_application_preps#refresh"
  end

  resources :interview_rounds, path: "interviews" do
    resource :interview_feedback, path: "feedbacks"

    # Round-specific interview prep
    resource :prep, controller: "interview_round_preps", only: [ :show ] do
      post :generate
      get :status
    end
  end
  resource :company_feedback, path: "feedback"

  member do
    patch :update_pipeline_stage
    patch :update_job_description
    patch :archive
    patch :reject
    patch :accept
    patch :reactivate
    patch :restore
  end

  collection do
    get :kanban
    post :quick_apply
  end
end

# =================================================================
# Lookups with Autocomplete
# =================================================================
resources :companies, only: [ :index, :create ], concerns: [ :autocompletable ]
resources :job_roles, only: [ :index, :create ], concerns: [ :autocompletable ]
resources :skill_tags, only: [ :index, :create ], concerns: [ :autocompletable ]
resources :categories, only: [ :index, :create ], concerns: [ :autocompletable ]

# =================================================================
# User Profile & Settings
# =================================================================
resource :profile, only: [ :show, :edit, :update ]

resource :settings, only: [ :show ] do
  patch :update_profile
  patch :update_general
  patch :update_notifications
  patch :update_ai_preferences
  patch :update_privacy
  patch :update_security
  delete "sessions/:session_id", action: :destroy_session, as: :revoke_session
  delete :destroy_all_sessions
  delete "disconnect/:provider", action: :disconnect_provider, as: :disconnect_provider
  post :export_data
  delete :account, action: :destroy_account
  post :trigger_sync
  patch :toggle_sync

  # Work Experience CRUD
  post :work_experience, action: :create_work_experience
  patch "work_experience/:id", action: :update_work_experience, as: :update_work_experience
  delete "work_experience/:id", action: :destroy_work_experience, as: :destroy_work_experience

  # Targets management
  patch :targets, action: :update_targets
  post "targets/add_role", action: :add_target_role, as: :add_target_role
  delete "targets/remove_role", action: :remove_target_role, as: :remove_target_role
  post "targets/add_company", action: :add_target_company, as: :add_target_company
  delete "targets/remove_company", action: :remove_target_company, as: :remove_target_company
  post "targets/add_domain", action: :add_target_domain, as: :add_target_domain
  delete "targets/remove_domain", action: :remove_target_domain, as: :remove_target_domain
end

# =================================================================
# Billing
# =================================================================
namespace :billing do
  post "checkout/:plan_key", to: "checkouts#create", as: :checkout
  get "return", to: "returns#show", as: :return
  get "portal", to: "portal#show", as: :portal

  resource :subscription, only: [] do
    post :cancel
    post :resume
  end
end

# =================================================================
# Signals (Email Intelligence) & Opportunities
# =================================================================
resources :signals, only: [ :index, :show ] do
  member do
    patch :match_application
    patch :ignore
    post :execute_action
  end
end

# Legacy inbox route redirects to signals
get "/inbox", to: redirect("/signals")
get "/inbox/:id", to: redirect("/signals/%{id}")

resources :opportunities, only: [ :index, :show ] do
  member do
    post :apply
    post :ignore
    post :restore
    patch :update_url
  end
end

# =================================================================
# Jobs & Leads
# =================================================================
resources :saved_jobs, only: [ :index, :create, :destroy ] do
  member do
    post :restore
    post :convert
  end
end

resources :archived_jobs, only: [ :index ]

# =================================================================
# Skills & Resumes
# =================================================================
resources :skills, only: [ :index, :show ]

resources :user_resumes, path: "resumes" do
  member do
    post :reanalyze
  end

  resources :resume_skills, path: "skills", only: [ :update, :destroy ] do
    collection do
      post :merge
      post :bulk_update
    end
  end
end
