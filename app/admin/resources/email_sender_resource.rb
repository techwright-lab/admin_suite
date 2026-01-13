# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Email Sender admin management
    #
    # Provides CRUD for email senders discovered during Gmail sync with company assignment.
    class EmailSenderResource < Admin::Base::Resource
      model EmailSender
      portal :ops
      section :email

      index do
        searchable :email, :name, :domain
        sortable :email, :created_at, default: :created_at
        paginate 30

        stats do
          stat :total, -> { EmailSender.count }
          stat :unassigned, -> { EmailSender.unassigned.count }, color: :amber
          stat :assigned, -> { EmailSender.assigned.count }, color: :green
          stat :auto_detected, -> { EmailSender.auto_detected.count }, color: :blue
          stat :verified, -> { EmailSender.verified.count }, color: :green
        end

        columns do
          column :email
          column :name
          column :domain
          column :company, ->(es) { es.company&.name || "—" }
          column :sender_type
          column :verified, ->(es) { es.verified? ? "Yes" : "No" }, type: :toggle, toggle_field: :verified
        end

        filters do
          filter :status, type: :select, options: [
            [ "All", "" ],
            [ "Unassigned", "unassigned" ],
            [ "Assigned", "assigned" ],
            [ "Auto Detected", "auto_detected" ],
            [ "Verified", "verified" ]
          ]
          filter :sender_type, type: :select, label: "Type", options: EmailSender.sender_types_for_select
          filter :sort, type: :select, options: [
            [ "Recently Added", "recent" ],
            [ "Email Count", "email_count" ],
            [ "Last Seen", "last_seen" ],
            [ "Alphabetical", "alphabetical" ]
          ]
        end
      end

      form do
        section "Sender Information" do
          field :email, readonly: true
          field :name
          field :domain, readonly: true
        end

        section "Assignment" do
          field :company_id, type: :searchable_select, label: "Company",
                collection: -> { Company.order(:name).pluck(:name, :id) },
                placeholder: "Search for a company..."
          field :sender_type, type: :select, collection: EmailSender.sender_types_for_select
          field :verified, type: :toggle, help: "Verified company assignment"
        end
      end

      show do
        sidebar do
          panel :info, title: "Sender Info", fields: [ :email, :name, :domain ]
          panel :assignment, title: "Assignment", fields: [ :company, :sender_type, :verified ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at, :updated_at ]
        end

        main do
          panel :emails, title: "Related Emails", association: :synced_emails, limit: 20, display: :list
        end
      end

      actions do
        action :verify, method: :post, unless: ->(es) { es.verified? }
        bulk_action :bulk_assign, label: "Assign to Company"
      end

      exportable :json, :csv
    end
  end
end
