# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Interview Application admin management
    #
    # Provides read-only access to interview applications with filtering and search.
    class InterviewApplicationResource < Admin::Base::Resource
      model InterviewApplication
      portal :ops
      section :applications

      index do
        searchable :user, :company, :job_role
        sortable :created_at, :applied_at, default: :created_at
        paginate 25

        stats do
          stat :total, -> { InterviewApplication.count }
          stat :active, -> { InterviewApplication.where(status: "active").count }, color: :green
          stat :with_rounds, -> { InterviewApplication.joins(:interview_rounds).distinct.count }, color: :blue
          stat :with_feedback, -> { InterviewApplication.joins(:company_feedback).distinct.count }, color: :amber
        end

        columns do
          column :user, ->(ia) { ia.user&.email_address }
          column :company, ->(ia) { ia.company&.name }
          column :job_role, ->(ia) { ia.job_role&.title }
          column :status, type: :label, label_color: ->(ia) {
            case ia.status.to_sym
            when :active then :indigo
            when :interviewing then :purple
            when :offer then :green
            when :rejected then :red
            when :archived then :slate
            else :slate
            end
          }
          column :pipeline_stage, type: :label, label_color: ->(ia) {
            case ia.pipeline_stage.to_sym
            when :applied then :indigo
            when :screening then :purple
            when :interviewing then :blue
            when :offer then :green
            when :closed then :red
            else :gray
            end
          }
          column :applied_at, ->(ia) { ia.applied_at&.strftime("%b %d, %Y") || "—" }
        end

        filters do
          filter :status, type: :select, options: [
            [ "All Statuses", "" ],
            [ "Active", "active" ],
            [ "Interviewing", "interviewing" ],
            [ "Offer", "offer" ],
            [ "Rejected", "rejected" ],
            [ "Withdrawn", "withdrawn" ]
          ]
          filter :pipeline_stage, type: :select, label: "Stage", options: [
            [ "All Stages", "" ],
            [ "Applied", "applied" ],
            [ "Screening", "screening" ],
            [ "Interviewing", "interviewing" ],
            [ "Offer", "offer" ],
            [ "Closed", "closed" ]
          ]
          filter :sort, type: :select, options: [
            [ "Recently Added", "recent" ],
            [ "Applied Date", "applied_at" ],
            [ "User Name", "user" ]
          ]
        end
      end

      show do
        sidebar do
          panel :status, title: "Status", fields: [ :status, :pipeline_stage ]
          panel :dates, title: "Key Dates", fields: [ :applied_at, :created_at, :updated_at ]
        end

        main do
          panel :user, title: "Applicant", fields: [ :user ]
          panel :position, title: "Position", fields: [ :company, :job_role, :job_listing ]
          panel :rounds, title: "Interview Rounds", association: :interview_rounds, limit: 20, display: :list
          panel :feedback, title: "Company Feedback", association: :company_feedback
          panel :emails, title: "Related Emails", association: :synced_emails, limit: 10, display: :list
        end
      end

      exportable :json, :csv
    end
  end
end
