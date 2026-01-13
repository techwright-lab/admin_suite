# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for User admin management
    #
    # Provides read-only access to users with connected accounts and sync visibility.
    class UserResource < Admin::Base::Resource
      model User
      portal :ops
      section :users

      index do
        searchable :email_address, :name
        sortable :name, :created_at, default: :created_at
        paginate 30

        stats do
          stat :total, -> { User.count }
          stat :with_gmail, -> { User.joins(:connected_accounts).where(connected_accounts: { provider: "google_oauth2" }).distinct.count }, color: :blue
          stat :sync_enabled, -> { User.joins(:connected_accounts).where(connected_accounts: { provider: "google_oauth2", sync_enabled: true }).distinct.count }, color: :green
          stat :admins, -> { User.where(is_admin: true).count }, color: :amber
        end

        columns do
          column :email_address, header: "Email"
          column :name
          column :is_admin, ->(u) { u.is_admin? ? "Admin" : "User" }, header: "Role"
          column :gmail_status, ->(u) {
            account = u.connected_accounts.find_by(provider: "google_oauth2")
            account ? (account.sync_enabled? ? "Syncing" : "Connected") : "Not Connected"
          }, header: "Gmail"
          column :created_at, ->(u) { u.created_at.strftime("%b %d, %Y") }
        end

        filters do
          filter :role, type: :select, options: [
            [ "All Users", "" ],
            [ "Admins Only", "admin" ],
            [ "Regular Users", "user" ]
          ]
          filter :gmail_status, type: :select, label: "Gmail", options: [
            [ "All", "" ],
            [ "Connected", "connected" ],
            [ "Not Connected", "not_connected" ],
            [ "Sync Enabled", "sync_enabled" ]
          ]
          filter :sort, type: :select, options: [
            [ "Recently Joined", "recent" ],
            [ "Name (A-Z)", "name" ],
            [ "Most Emails", "email_count" ]
          ]
        end
      end

      show do
        sidebar do
          panel :account, title: "Account", fields: [ :email_address, :is_admin, :email_verified_at ]
          panel :billing, title: "Billing", fields: [ :billing_admin_access? ]
          panel :timestamps, title: "Activity", fields: [ :created_at, :updated_at ]
        end

        main do
          panel :profile, title: "Profile", fields: [ :name ]
          panel :connected_accounts, title: "Connected Accounts",
                association: :connected_accounts,
                display: :table,
                columns: [ :provider, :sync_enabled, :created_at ],
                link_to: :internal_developer_ops_connected_account_path
          panel :threads, title: "Chat Threads",
                association: :chat_threads,
                limit: 5,
                display: :list,
                link_to: :internal_developer_assistant_thread_path
          panel :applications, title: "Interview Applications",
                association: :interview_applications,
                limit: 10,
                display: :list,
                link_to: :internal_developer_ops_interview_application_path
          panel :emails, title: "Recent Synced Emails",
                association: :synced_emails,
                limit: 10,
                display: :table,
                columns: [ :subject, :from_address, :synced_at ],
                link_to: :internal_developer_ops_synced_email_path
        end
      end

      actions do
        action :resend_verification_email, method: :post, label: "Resend Verification Email",
               confirm: "Send a new verification email to this user?",
               unless: ->(u) { u.email_verified? }
        action :grant_admin, method: :post, label: "Grant Admin Privileges",
               confirm: "Grant admin privileges to this user? They will have full access to the developer portal.",
               unless: ->(u) { u.admin? }
        action :revoke_admin, method: :post, label: "Revoke Admin Privileges",
               confirm: "Revoke admin privileges from this user?",
               if: ->(u) { u.admin? }
        action :grant_billing_admin_access, method: :post, label: "Grant Billing Admin Access",
               confirm: "Grant Admin/Developer billing access (all features) to this user?",
               unless: ->(u) { Billing::AdminAccessService.new(user: u).active? }
        action :revoke_billing_admin_access, method: :post, label: "Revoke Billing Admin Access",
               confirm: "Revoke Admin/Developer billing access from this user?",
               if: ->(u) { Billing::AdminAccessService.new(user: u).active? }
      end

      exportable :json
    end
  end
end
