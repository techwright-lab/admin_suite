# frozen_string_literal: true

# API Routes
#
# RESTful JSON API endpoints for frontend consumption
# All routes are namespaced under /api/v1

namespace :api do
  namespace :v1 do
    # Job Roles - search and create
    resources :job_roles, only: [ :index, :create ]

    # Companies - search and create
    resources :companies, only: [ :index, :create ]

    # Domains - search and create
    resources :domains, only: [ :index, :create ]

    # Departments - list departments (job role categories)
    resources :departments, only: [ :index ]
  end
end
