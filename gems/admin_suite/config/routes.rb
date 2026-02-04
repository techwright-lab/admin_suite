# frozen_string_literal: true

AdminSuite::Engine.routes.draw do
  root to: "dashboard#index"

  # Docs viewer (host filesystem-backed). Must be defined before `:portal` route.
  get "docs(/)", to: "docs#index", as: :docs
  get "docs/*path", to: "docs#show", as: :doc, format: false

  # Portal dashboards (e.g. /ops, /email). Accept optional trailing slash.
  get ":portal(/)", to: "portals#show", as: :portal

  # Generic resource routes (dynamic)
  scope ":portal/:resource_name" do
    get "/", to: "resources#index", as: :resources
    get "/new", to: "resources#new", as: :new_resource
    post "/", to: "resources#create"
    get "/:id", to: "resources#show", as: :resource
    get "/:id/edit", to: "resources#edit", as: :edit_resource
    patch "/:id", to: "resources#update"
    put "/:id", to: "resources#update"
    delete "/:id", to: "resources#destroy"

    post "/:id/execute_action/:action_name", to: "resources#execute_action", as: :execute_action
    post "/bulk_action/:action_name", to: "resources#bulk_action", as: :bulk_action
  end

  post ":portal/:resource_name/:id/toggle", to: "resources#toggle", as: :resource_toggle
end
