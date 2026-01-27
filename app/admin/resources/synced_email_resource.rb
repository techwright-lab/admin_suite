# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Synced Email admin management
    #
    # Provides viewing and manual matching of synced emails from Gmail.
    # Includes signal extraction debugging information.
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
          stat :pending_extraction, -> { SyncedEmail.where(extraction_status: "pending").count }, color: :amber
          stat :extracted, -> { SyncedEmail.where(extraction_status: "completed").count }, color: :green
        end

        columns do
          column :subject, ->(se) { se.subject&.truncate(50) }
          column :from_email, header: "From"
          column :user, ->(se) { se.user&.email_address }
          column :status, type: :label, label_color: ->(se) {
            case se.status.to_sym
            when :pending then :amber
            when :processed then :green
            when :ignored then :slate
            when :failed then :red
            when :auto_ignored then :slate
            else :gray
            end
          }
          column :email_type, header: "Type"
          column :extraction_status, type: :label, label_color: ->(se) {
            case se.extraction_status.to_sym
            when :pending then :amber
            when :processing then :indigo
            when :completed then :green
            when :failed then :red
            when :skipped then :purple
            else :gray
            end
          }
          column :matched, type: :label, label_color: ->(se) { se.interview_application_id? ? :green : :amber }
          column :email_date, ->(se) { se.email_date&.strftime("%b %d, %H:%M") }
        end

        filters do
          filter :status, type: :select, options: -> {
            [ [ "All Statuses", "" ] ] + SyncedEmail::STATUSES.map { |s| [ s.to_s.humanize, s.to_s ] }
          }
          filter :email_type, type: :select, label: "Type", options: -> {
            [ [ "All Types", "" ] ] + SyncedEmail::EMAIL_TYPES.map { |t| [ t.humanize, t ] }
          }
          filter :extraction_status, type: :select, label: "Extraction", options: -> {
            [ [ "All", "" ] ] + SyncedEmail::EXTRACTION_STATUSES.map { |s| [ s.humanize, s ] }
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

        section "Extraction Status" do
          field :extraction_status, type: :select, collection: [
            [ "Pending", "pending" ],
            [ "Processing", "processing" ],
            [ "Completed", "completed" ],
            [ "Failed", "failed" ],
            [ "Skipped", "skipped" ]
          ]
        end
      end

      show do
        sidebar do
          panel :sender, title: "Sender", fields: [ :from_email, :from_name, :email_sender ]
          panel :status, title: "Status", fields: [ :status, :email_type ]
          panel :matching, title: "Matching", fields: [ :interview_application ]
          panel :timestamps, title: "Dates", fields: [ :email_date, :created_at ]
          panel :extraction, title: "Signal Extraction", fields: [
            :extraction_status, :extraction_confidence, :extracted_at
          ]
        end

        main do
          panel :email, title: "Email Content", fields: [ :subject, :body_snippet ]
          panel :extracted_intelligence, title: "Extracted Intelligence", fields: [
            :signal_company_name, :signal_company_website, :signal_company_careers_url, :signal_company_domain,
            :signal_recruiter_name, :signal_recruiter_email, :signal_recruiter_title, :signal_recruiter_linkedin,
            :signal_job_title, :signal_job_department, :signal_job_location, :signal_job_url, :signal_job_salary_hint
          ]
          panel :actions_and_links, title: "Actions & Links", fields: [
            :signal_action_links, :signal_suggested_actions
          ]
          panel :raw_extraction, title: "Raw Extracted Data (JSON)", fields: [ :extracted_data ]
        end
      end

      actions do
        action :mark_processed, method: :post, if: ->(se) { se.status == "pending" }
        action :mark_needs_review, method: :post, unless: ->(se) { se.pending? && se.interview_application_id.nil? }
        action :ignore, method: :post, unless: ->(se) { se.ignored? }
        action :trigger_extraction, method: :post, if: ->(se) { se.extraction_status.in?([ "pending", "failed" ]) }
      end

      exportable :json

      # Custom action to trigger signal extraction
      def trigger_extraction
        ProcessSignalExtractionJob.perform_later(resource.id)
        redirect_to show_path, notice: "Signal extraction queued"
      end
    end
  end
end
