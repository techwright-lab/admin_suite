# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for InterviewRound admin management
    #
    # Provides read operations for viewing interview rounds.
    class InterviewRoundResource < Admin::Base::Resource
      model InterviewRound
      portal :ops
      section :support

      index do
        sortable :scheduled_at, :created_at, default: :scheduled_at
        paginate 30

        stats do
          stat :total, -> { InterviewRound.count }
          stat :scheduled, -> { InterviewRound.where("scheduled_at > ?", Time.current).count }, color: :blue
          stat :completed, -> { InterviewRound.where("scheduled_at < ?", Time.current).count }, color: :green
        end

        columns do
          column :id
          column :interview_application, ->(ir) { "App ##{ir.interview_application_id}" }
          column :round_type
          column :scheduled_at, ->(ir) { ir.scheduled_at&.strftime("%b %d, %Y %H:%M") }
          column :status
        end

        filters do
          filter :round_type, type: :select, options: [
            [ "All Types", "" ],
            [ "Phone Screen", "phone_screen" ],
            [ "Technical", "technical" ],
            [ "Onsite", "onsite" ],
            [ "Final", "final" ]
          ]
          filter :status, type: :select, options: [
            [ "All Statuses", "" ],
            [ "Scheduled", "scheduled" ],
            [ "Completed", "completed" ],
            [ "Cancelled", "cancelled" ]
          ]
        end
      end

      show do
        section :details, fields: [
          :round_type, :status, :scheduled_at, :duration_minutes,
          :location, :notes, :created_at, :updated_at
        ]
        section :application, fields: [ :interview_application ]
        section :feedback, association: :interview_feedback
      end

      exportable :json
    end
  end
end
