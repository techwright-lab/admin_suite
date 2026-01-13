# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Synced Email admin management
    #
    # Provides viewing and manual matching of synced emails from Gmail.
    class SyncedEmailResource < Admin::Base::Resource
      model SyncedEmail
      portal :ops
      section :email

      index do
        searchable :subject, :from_email, :from_name
        sortable :email_date, :subject, default: :email_date
        paginate 30

        stats do
          stat :total, -> { SyncedEmail.count }
          stat :pending, -> { SyncedEmail.where(status: :pending).count }, color: :amber
          stat :processed, -> { SyncedEmail.where(status: :processed).count }, color: :green
          stat :needs_review, -> { SyncedEmail.needs_review.count }, color: :red
          stat :matched, -> { SyncedEmail.matched.count }, color: :blue
        end

        columns do
          column :subject, ->(se) { se.subject&.truncate(50) }
          column :from_email, header: "From"
          column :user, ->(se) { se.user&.email_address }
          column :status
          column :email_type, header: "Type"
          column :matched, ->(se) { se.interview_application_id? ? "Yes" : "No" }
          column :email_date, ->(se) { se.email_date&.strftime("%b %d, %H:%M") }
        end

        filters do
          filter :status, type: :select, options: -> {
            [ [ "All Statuses", "" ] ] + SyncedEmail::STATUSES.map { |s| [ s.to_s.humanize, s.to_s ] }
          }
          filter :email_type, type: :select, label: "Type", options: -> {
            [ [ "All Types", "" ] ] + SyncedEmail::EMAIL_TYPES.map { |t| [ t.humanize, t ] }
          }
          filter :matched, type: :select, options: [
            [ "All", "" ],
            [ "Matched", "matched" ],
            [ "Unmatched", "unmatched" ]
          ]
          filter :sort, type: :select, options: [
            [ "Newest First", "recent" ],
            [ "Oldest First", "oldest" ],
            [ "Subject", "subject" ]
          ]
        end
      end

      form do
        section "Email Matching" do
          field :interview_application_id, type: :number, label: "Application ID"
          field :email_type, type: :select, collection: [ [ "Unknown", "" ] ] + SyncedEmail::EMAIL_TYPES.map { |t| [ t.humanize, t ] }
          field :status, type: :select, collection: [
            [ "Pending", "pending" ],
            [ "Processed", "processed" ],
            [ "Ignored", "ignored" ],
            [ "Failed", "failed" ],
            [ "Auto Ignored", "auto_ignored" ]
          ]
        end
      end

      show do
        sidebar do
          panel :sender, title: "Sender", fields: [ :from_email, :from_name, :email_sender ]
          panel :status, title: "Status", fields: [ :status, :email_type ]
          panel :matching, title: "Matching", fields: [ :interview_application ]
          panel :timestamps, title: "Dates", fields: [ :email_date, :created_at ]
        end

        main do
          panel :email, title: "Email Content", fields: [ :subject, :body_snippet ]
        end
      end

      actions do
        action :mark_processed, method: :post, if: ->(se) { se.status == "pending" }
        action :mark_needs_review, method: :post, unless: ->(se) { se.pending? && se.interview_application_id.nil? }
        action :ignore, method: :post, unless: ->(se) { se.ignored? }
      end

      exportable :json
    end
  end
end
