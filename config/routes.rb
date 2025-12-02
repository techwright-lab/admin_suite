Rails.application.routes.draw do
  mount_avo
  # Mount engines

  namespace :internal do
    mount MissionControl::Jobs::Engine, at: "/jobs"
    mount Avo::Engine, at: "/admin"
  end

  # Public pages (marketing, landing pages)
  # Using scope with module to keep controllers in Public:: but without /public in URLs
  scope module: :public do
    resource :contact, only: [ :show, :create ]
  end

  # Admin routes
  namespace :admin do
    root to: "dashboard#index"
    get "scraping_metrics", to: "scraping_metrics#index"
    resources :job_listings, only: [ :index, :show, :edit, :update, :destroy ]
    resources :ai_extraction_logs, only: [ :index, :show ]
    resources :html_scraping_logs, only: [ :index, :show ]
    resources :scraping_attempts, only: [ :index, :show ]
    resources :scraping_events, only: [ :show ]

    # Users & Email management
    resources :users, only: [ :index, :show ]
    resources :email_senders, only: [ :index, :show, :edit, :update ] do
      collection do
        post :bulk_assign
      end
    end

    # Support Tickets
    resources :support_tickets, only: [ :index, :show, :update ]
  end

  # Authentication routes
  resource :session
  resources :passwords, param: :token
  resources :registrations, only: [ :new, :create ]
  post "email_verification", to: "email_verifications#create", as: :resend_email_verification
  get "email_verification/:token", to: "email_verifications#show", as: :email_verification

  # Main application routes
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

  # Company and Job Role management
  resources :companies, only: [ :index, :create ] do
    collection do
      get :autocomplete
    end
  end

  resources :job_roles, only: [ :index, :create ] do
    collection do
      get :autocomplete
    end
  end

  # Job Listings (managed in admin panel only)
  # Users view job details via the interview application "Job Details" tab
  # resources :job_listings # Moved to admin namespace


  # Profile
  resource :profile, only: [ :show, :edit, :update ]

  # Settings
  resource :settings, only: [ :show ] do
    patch :update_profile
    patch :update_general
    patch :update_notifications
    patch :update_ai_preferences
    patch :update_privacy
    patch :update_security
    delete "sessions/:session_id", action: :destroy_session, as: :destroy_session
    delete :destroy_all_sessions
    delete "disconnect/:provider", action: :disconnect_provider, as: :disconnect_provider
    post :export_data
    delete :account, action: :destroy_account
    post :trigger_sync
    patch :toggle_sync
  end

  # Inbox for synced emails
  resources :inbox, only: [ :index, :show ] do
    member do
      patch :match_application
      patch :ignore
    end
  end

  # OAuth callbacks
  get "/auth/:provider/callback", to: "oauth_callbacks#create", as: :oauth_callback
  post "/auth/:provider/callback", to: "oauth_callbacks#create" # Also handle POST callbacks
  get "/auth/failure", to: "oauth_callbacks#failure", as: :oauth_failure

  # AI Assistant
  namespace :ai_assistant do
    post "ask", to: "queries#ask"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Dashboard route for authenticated users
  get "dashboard", to: "interview_applications#index", as: :dashboard

  # Root path - public homepage
  root "public/home#index"
end
