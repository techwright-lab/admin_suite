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
  resources :interview_rounds, path: "interviews" do
    resource :interview_feedback, path: "feedbacks"
  end
  resource :company_feedback, path: "feedback"

  member do
    patch :update_pipeline_stage
    patch :archive
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
end

# =================================================================
# Email & Opportunities
# =================================================================
resources :inbox, only: [ :index, :show ] do
  member do
    patch :match_application
    patch :ignore
  end
end

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
resources :skills, only: [ :index ]

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
