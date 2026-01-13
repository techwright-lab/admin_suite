# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for CompanyFeedback admin management
    #
    # Provides read operations for viewing company feedback from users.
    class CompanyFeedbackResource < Admin::Base::Resource
      model CompanyFeedback
      portal :ops
      section :support

      index do
        sortable :created_at, default: :created_at
        paginate 30

        stats do
          stat :total, -> { CompanyFeedback.count }
          stat :this_month, -> { CompanyFeedback.where("created_at >= ?", 1.month.ago).count }, color: :blue
        end

        columns do
          column :id
          column :company, ->(cf) { cf.interview_application&.company&.name }
          column :user, ->(cf) { cf.interview_application&.user&.email_address }
          column :rating
          column :created_at, ->(cf) { cf.created_at.strftime("%b %d, %Y") }
        end

        filters do
          filter :rating, type: :select, options: (1..5).map { |n| [ "#{n} Stars", n ] }
        end
      end

      show do
        section :details, fields: [ :rating, :created_at, :updated_at ]
        section :feedback, fields: [ :feedback_text ]
        section :application, fields: [ :interview_application ]
      end

      exportable :json
    end
  end
end
