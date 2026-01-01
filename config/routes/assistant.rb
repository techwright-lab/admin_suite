# frozen_string_literal: true

# Assistant routes
#
# AI Assistant user interface and API endpoints

# AI Assistant API
namespace :ai_assistant do
  post "ask", to: "queries#ask"

  resources :tool_executions, only: [] do
    member do
      post :enqueue
      post :approve
    end
  end
end

# Assistant UI (authenticated)
namespace :assistant do
  root to: "threads#index"

  # Widget routes
  get :widget, to: "widgets#show"
  get "widget/threads", to: "widgets#threads", as: :widget_threads
  post "widget/new_thread", to: "widgets#new_thread", as: :widget_new_thread

  resources :threads, only: [ :index, :show, :create, :new ], param: :uuid do
    resources :messages, only: [ :create ]

    resources :tool_executions, only: [], param: :uuid do
      member do
        post :approve
        post :enqueue
      end
    end
  end
end
