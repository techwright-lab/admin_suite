Rails.application.routes.draw do
  mount_avo
  # Mount engines

  namespace :internal do
    mount MissionControl::Jobs::Engine, at: "/jobs"
    mount Avo::Engine, at: "/admin"
    mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
  end

  # Public pages (marketing, landing pages)
  # Using scope with module to keep controllers in Public:: but without /public in URLs
  scope module: :public do
    resource :contact, only: [ :show, :create ]
    get "privacy", to: "legal#privacy", as: :privacy
    get "terms", to: "legal#terms", as: :terms
    get "cookies", to: "legal#cookies_policy", as: :cookies

    resources :blog, only: [ :index, :show ], param: :slug
    get "blog/tags/:tag", to: "blog_tags#show", as: :blog_tag

    post "newsletter/subscribe", to: "newsletter_subscriptions#create", as: :newsletter_subscribe
    get "newsletter/unsubscribe/:signed_id", to: "newsletter_subscriptions#destroy", as: :newsletter_unsubscribe

    get "sitemap", to: "sitemaps#show", defaults: { format: :xml }, as: :sitemap
  end

  # Admin routes
  namespace :admin do
    root to: "dashboard#index"
    get "scraping_metrics", to: "scraping_metrics#index"
    resources :blog_posts
    resources :blog_tags, only: [ :index ]
    get "docs", to: "docs#index", as: :docs
    get "docs/*path", to: "docs#show", as: :doc
    resources :job_listings, only: [ :index, :show, :edit, :update, :destroy ] do
      member do
        post :disable
        post :enable
      end
    end
    # AI Namespace - LLM Prompts and API Logs
    namespace :ai do
      resources :llm_prompts do
        member do
          post :activate
          post :duplicate
        end
      end
      resources :llm_api_logs, only: [ :index, :show ]
    end
    resources :html_scraping_logs, only: [ :index, :show ]
    resources :scraping_attempts, only: [ :index, :show ] do
      member do
        post :mark_failed
        post :retry_attempt
      end
      collection do
        post :cleanup_stuck
      end
    end
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

    # Company and Job Role management
    resources :companies, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
      member do
        post :disable
        post :enable
        get :merge
        post :merge_into
      end
    end

    resources :job_roles, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
      member do
        post :disable
        post :enable
        get :merge
        post :merge_into
      end
    end

    # Settings
    resources :settings, only: [ :index, :show, :new, :create, :edit, :update ]

    # LLM Provider Configs
    resources :llm_provider_configs, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
      member do
        post :test_provider
      end
    end

    # Content Management
    resources :skill_tags, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
      member do
        post :disable
        post :enable
        get :merge
        post :merge_into
      end
    end

    resources :categories, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
      member do
        post :disable
        post :enable
        get :merge
        post :merge_into
      end
    end

    # Interview Applications (read-only for support/debugging)
    resources :interview_applications, only: [ :index, :show ]

    # Email Management
    resources :synced_emails, only: [ :index, :show, :edit, :update ]

    # OAuth & Accounts
    resources :connected_accounts, only: [ :index, :show ]
  end

  # Authentication routes (user-friendly URLs)
  get "login", to: "sessions#new", as: :new_session
  post "login", to: "sessions#create", as: :session
  delete "logout", to: "sessions#destroy", as: :logout

  get "signup", to: "registrations#new", as: :new_registration
  post "signup", to: "registrations#create", as: :registrations

  resources :passwords, param: :token
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

  resources :skill_tags, only: [ :index, :create ] do
    collection do
      get :autocomplete
    end
  end

  resources :categories, only: [ :index, :create ] do
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
    delete "sessions/:session_id", action: :destroy_session, as: :revoke_session
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

  # Opportunities from recruiter outreach
  resources :opportunities, only: [ :index, :show ] do
    member do
      post :apply
      post :ignore
      patch :update_url
    end
  end

  # Saved jobs (bookmarked leads)
  resources :saved_jobs, only: [ :index, :create, :destroy ] do
    member do
      post :restore
      post :convert
    end
  end

  # Archived jobs (opportunities + saved jobs)
  resources :archived_jobs, only: [ :index ]

  # Skills dashboard
  resources :skills, only: [ :index ]

  # Resumes and skill profile
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
  get "dashboard", to: "dashboard#index", as: :dashboard

  # Root path - public homepage
  root "public/home#index"
end
