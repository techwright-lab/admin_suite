# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Support Ticket admin management
    #
    # Provides listing and status management for support tickets.
    class SupportTicketResource < Admin::Base::Resource
      model SupportTicket
      portal :ops
      section :support

      index do
        searchable :name, :email, :subject, :message
        sortable :created_at, :name, :email, default: :created_at
        paginate 30

        stats do
          stat :total, -> { SupportTicket.count }
          stat :open, -> { SupportTicket.open.count }, color: :amber
          stat :in_progress, -> { SupportTicket.in_progress.count }, color: :blue
          stat :resolved, -> { SupportTicket.resolved.count }, color: :green
          stat :closed, -> { SupportTicket.closed.count }, color: :slate
        end

        columns do
          column :subject
          column :name
          column :email
          column :status
          column :user, ->(st) { st.user ? "Registered" : "Guest" }, header: "Type"
          column :created_at, ->(st) { st.created_at.strftime("%b %d, %H:%M") }
        end

        filters do
          filter :status, type: :select, options: [
            ["All Statuses", ""],
            ["Open", "open"],
            ["In Progress", "in_progress"],
            ["Resolved", "resolved"],
            ["Closed", "closed"]
          ]
          filter :user_type, type: :select, label: "Sender", options: [
            ["All", ""],
            ["Registered Users", "registered"],
            ["Guests", "guest"]
          ]
          filter :sort, type: :select, options: [
            ["Newest First", "recent"],
            ["Oldest First", "oldest"],
            ["Name (A-Z)", "name"]
          ]
        end
      end

      form do
        section "Ticket Status" do
          field :status, type: :select, collection: [
            ["Open", "open"],
            ["In Progress", "in_progress"],
            ["Resolved", "resolved"],
            ["Closed", "closed"]
          ]
        end
      end

      show do
        sidebar do
          panel :sender, title: "Sender", fields: [:name, :email, :user]
          panel :status, title: "Status", fields: [:status]
          panel :timestamps, title: "Timestamps", fields: [:created_at, :updated_at]
        end
        
        main do
          panel :ticket, title: "Ticket Content", fields: [:subject, :message]
        end
      end

      actions do
        action :mark_in_progress, method: :post, label: "Start", if: ->(st) { st.status == "open" }
        action :resolve, method: :post, if: ->(st) { st.status == "in_progress" }
        action :close, method: :post, if: ->(st) { st.status == "resolved" }
        action :reopen, method: :post, if: ->(st) { st.status == "closed" }
      end

      exportable :json, :csv
    end
  end
end

