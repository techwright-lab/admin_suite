# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Connected Account admin management
    #
    # Provides read-only access to OAuth connected accounts for debugging.
    class ConnectedAccountResource < Admin::Base::Resource
      model ConnectedAccount
      portal :ops
      section :users

      index do
        searchable :email
        sortable :created_at, :last_synced_at, default: :created_at
        paginate 30

        stats do
          stat :total, -> { ConnectedAccount.count }
          stat :google, -> { ConnectedAccount.google.count }, color: :blue
          stat :sync_enabled, -> { ConnectedAccount.sync_enabled.count }, color: :green
          stat :expired, -> { ConnectedAccount.expired.count }, color: :red
          stat :valid, -> { ConnectedAccount.valid_tokens.count }, color: :green
        end

        columns do
          column :user, ->(ca) { ca.user&.email_address }
          column :provider
          column :email
          column :sync_enabled, ->(ca) { ca.sync_enabled? ? "Yes" : "No" }, header: "Sync"
          column :token_status, ->(ca) {
            if ca.token_expired?
              "Expired"
            elsif ca.expires_at && ca.expires_at < 5.minutes.from_now
              "Expiring"
            else
              "Valid"
            end
          }, header: "Token"
          column :last_synced_at, ->(ca) { ca.last_synced_at&.strftime("%b %d, %H:%M") || "Never" }
        end

        filters do
          filter :provider, type: :select, options: [
            ["All Providers", ""],
            ["Google", "google_oauth2"]
          ]
          filter :sync_enabled, type: :select, label: "Sync", options: [
            ["All", ""],
            ["Enabled", "true"],
            ["Disabled", "false"]
          ]
          filter :token_status, type: :select, label: "Token", options: [
            ["All", ""],
            ["Valid", "valid"],
            ["Expired", "expired"],
            ["Expiring Soon", "expiring_soon"]
          ]
          filter :sort, type: :select, options: [
            ["Recently Added", "recent"],
            ["Last Synced", "last_synced"],
            ["User Name", "user"]
          ]
        end
      end

      show do
        sidebar do
          panel :account, title: "Account", fields: [:email, :provider, :uid]
          panel :sync, title: "Sync Status", fields: [:sync_enabled, :last_synced_at]
          panel :token, title: "Token", fields: [:expires_at]
          panel :timestamps, title: "Timestamps", fields: [:created_at, :updated_at]
        end
        
        main do
          panel :user, title: "User", fields: [:user]
          panel :emails, title: "Recent Synced Emails", association: :synced_emails, limit: 20, display: :list
        end
      end

      exportable :json
    end
  end
end

