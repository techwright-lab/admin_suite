# frozen_string_literal: true

# Developer Portal Routes
#
# New admin framework at /internal/developer for testing and comparison
# with the existing /admin portal. Uses the Admin::Base::Resource framework.
#
# Structure:
#   /internal/developer           - Main dashboard
#   /internal/developer/login     - TechWright SSO login page
#   /internal/developer/logout    - Logout
#   /internal/developer/ops/*     - Ops Portal (Content, Users, Email, Scraping)
#   /internal/developer/ai/*      - AI Portal (LLM Prompts, Provider Configs)
#   /internal/developer/assistant/* - Assistant Portal (Threads, Tools, Memory)

# =================================================================
# Developer Portal Authentication (TechWright SSO)
# =================================================================
get "/internal/developer/login", to: "internal/developer/sessions#new", as: :internal_developer_login
delete "/internal/developer/logout", to: "internal/developer/sessions#destroy", as: :internal_developer_logout

# TechWright OAuth callback - separate from regular OAuth callbacks
get "/auth/techwright/callback", to: "internal/developer/sessions#create"
post "/auth/techwright/callback", to: "internal/developer/sessions#create"

namespace :internal do
  namespace :developer do
    root to: "dashboard#index"

    # Documentation Viewer
    resources :docs, only: [ :index ], path: "docs" do
      collection do
        get "*path", action: :show, as: :show, format: false
      end
    end

    # =================================================================
    # Route Concerns - Shared route patterns
    # =================================================================
    concern :toggleable do
      member do
        post :enable
        post :disable
        post :toggle
      end
    end

    concern :mergeable do
      member do
        get :merge
        post :merge_into
      end
    end

    concern :exportable do
      member do
        get :export
      end
    end

    concern :publishable do
      member do
        post :publish
        post :unpublish
      end
    end

    concern :status_manageable do
      member do
        post :open
        post :close
        post :resolve
      end
    end

    # =================================================================
    # Ops Portal - Content, Users, Email & Scraping Management
    # =================================================================
    namespace :ops do
      root to: "dashboard#index"

      # Content Resources
      resources :companies, concerns: [ :toggleable, :mergeable ]
      resources :job_roles, concerns: [ :toggleable, :mergeable ]
      resources :categories, concerns: [ :toggleable, :mergeable ]
      resources :skill_tags, concerns: [ :toggleable, :mergeable ]
      resources :job_listings do
        member do
          post :disable
          post :enable
        end
      end
      resources :interview_applications, only: [ :index, :show ]
      resources :interview_rounds, only: [ :index, :show ]
      resources :interview_round_types, concerns: [ :toggleable ]
      resources :company_feedbacks, only: [ :index, :show ]

      # Blog Resources
      resources :blog_posts do
        member do
          post :publish
          post :unpublish
        end
      end

      # User Resources
      resources :users, only: [ :index, :show ] do
        member do
          post :resend_verification_email
          post :grant_admin
          post :revoke_admin
          post :grant_billing_admin_access
          post :revoke_billing_admin_access
        end
      end
      resources :connected_accounts, only: [ :index, :show ]
      resources :support_tickets do
        member do
          post :mark_in_progress
          post :resolve
          post :close
          post :reopen
        end
      end

      # Email Resources
      resources :email_senders do
        member do
          post :verify
        end
        collection do
          post :bulk_assign
        end
      end
      resources :synced_emails do
        member do
          post :mark_processed
          post :mark_needs_review
          post :ignore
        end
      end

      # Scraping Resources
      resources :scraping_attempts, only: [ :index, :show ] do
        member do
          post :mark_failed
          post :retry_attempt
        end
        collection do
          post :cleanup_stuck
        end
      end
      resources :scraping_events, only: [ :index, :show ]
      resources :html_scraping_logs, only: [ :index, :show ]

      # System Resources
      resources :settings
    end

    # =================================================================
    # AI Portal - LLM & Machine Learning Management
    # =================================================================
    namespace :ai do
      root to: "dashboard#index"

      resources :llm_prompts do
        member do
          post :activate
          post :duplicate
        end
      end

      resources :llm_provider_configs do
        member do
          post :test_provider
          post :enable
          post :disable
        end
      end

      resources :llm_api_logs, only: [ :index, :show ]
    end

    # =================================================================
    # Assistant Portal - Chat, Tools & Memory Management
    # =================================================================
    namespace :assistant do
      root to: "dashboard#index"

      # Chat Resources
      resources :threads, only: [ :index, :show ], concerns: [ :exportable ]
      resources :turns, only: [ :index, :show ], concerns: [ :exportable ]
      resources :events, only: [ :index, :show ]

      # Tool Resources
      resources :tools do
        member do
          post :enable
          post :disable
        end
      end
      resources :tool_executions, only: [ :index, :show ], concerns: [ :exportable ] do
        member do
          post :approve
          post :enqueue
          post :replay
        end
        collection do
          post :bulk_approve
          post :bulk_enqueue
        end
      end

      # Memory Resources
      resources :memory_proposals, only: [ :index, :show ]
      resources :thread_summaries, only: [ :index, :show ]
      resources :user_memories, only: [ :index, :show, :destroy ]
    end

    # =================================================================
    # Payments Portal - Billing Catalog & Payment Provider Sync
    # =================================================================
    namespace :payments do
      root to: "dashboard#index"

      resources :plans
      resources :features
      resources :plan_entitlements
      resources :provider_mappings

      resources :subscriptions, only: [ :index, :show ]
      resources :webhook_events, only: [ :index, :show ] do
        member do
          post :replay
        end
      end
    end

    # Generic resource action routes (for resources not explicitly defined)
    scope ":portal/:resource_name" do
      post ":id/execute_action/:action_name", to: "resources#execute_action", as: :execute_action
      post "bulk_action/:action_name", to: "resources#bulk_action", as: :bulk_action
    end

    # =================================================================
    # Generic toggle endpoint for any resource with toggle columns
    # =================================================================
    post ":portal/:resource_name/:id/toggle", to: "resources#toggle", as: :resource_toggle
  end
end
