# frozen_string_literal: true

module Admin
  module Portals
    # Operations Portal
    #
    # Contains resources for day-to-day operations including:
    # - User management
    # - Email management
    # - Content management
    # - Scraping operations
    # - Support tickets
    class OpsPortal < Admin::Base::Portal
      name "Operations"
      icon :building
      path_prefix "/admin/ops"

      section :dashboard do
        label "Dashboard"
        icon :home
        resources :dashboard
      end

      section :users_email do
        label "Users & Email"
        icon :users
        resources :users, :email_senders, :connected_accounts, :synced_emails
      end

      section :content do
        label "Content"
        icon :document
        resources :blog_posts, :companies, :job_roles, :job_listings, :categories, :skill_tags
      end

      section :scraping do
        label "Scraping"
        icon :code
        resources :scraping_metrics, :scraping_attempts, :scraping_events, :html_scraping_logs
      end

      section :support do
        label "Support"
        icon :chat
        resources :support_tickets, :interview_applications
      end

      section :system do
        label "System"
        icon :cog
        resources :settings
      end
    end
  end
end

