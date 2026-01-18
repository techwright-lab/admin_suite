# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for InterviewRoundType admin management
    #
    # Provides CRUD operations for managing interview round types per department.
    # Round types with no category are universal (available to all departments).
    class InterviewRoundTypeResource < Admin::Base::Resource
      model InterviewRoundType
      portal :ops
      section :content

      index do
        searchable :name, :slug
        sortable :name, :position, :created_at, default: :position
        paginate 30

        stats do
          stat :total, -> { InterviewRoundType.count }
          stat :universal, -> { InterviewRoundType.universal.count }, color: :blue
          stat :enabled, -> { InterviewRoundType.enabled.count }, color: :green
        end

        columns do
          column :name
          column :slug
          column :department, ->(rt) { rt.category&.name || "Universal" }
          column :position
          column :rounds_count, ->(rt) { rt.interview_rounds.count }, header: "Rounds"
          column :status, ->(rt) { rt.disabled? ? "Disabled" : "Enabled" }
        end

        filters do
          filter :category_id, type: :select, label: "Department",
                 options: -> { [ [ "Universal", "nil" ] ] + Category.departments.pluck(:name, :id) }
          filter :disabled_at, type: :select, label: "Status",
                 options: [ [ "Enabled", "nil" ], [ "Disabled", "not_nil" ] ]
        end
      end

      form do
        field :name, required: true, placeholder: "Round type name (e.g., 'Coding Interview')"
        field :slug, required: true, placeholder: "Slug (e.g., 'coding')"
        field :category_id, type: :select, label: "Department",
              collection: -> { [ [ "Universal (all departments)", nil ] ] + Category.departments.pluck(:name, :id) }
        field :description, type: :textarea, rows: 3, placeholder: "Optional description or admin notes"
        field :position, type: :number, default: 0, hint: "Lower numbers appear first"
      end

      show do
        sidebar do
          panel :timestamps, title: "Timestamps", fields: [ :created_at, :updated_at ]
          panel :status, title: "Status", fields: [ :disabled_at ]
        end

        main do
          panel :details, title: "Details", fields: [ :name, :slug, :description, :position ]
          panel :department, title: "Department", fields: [ :category ]
          panel :interview_rounds, title: "Interview Rounds", association: :interview_rounds, limit: 10, display: :list
        end
      end

      actions do
        action :disable, method: :post, confirm: "Disable this round type?"
        action :enable, method: :post
        bulk_action :bulk_disable
        bulk_action :bulk_enable
      end

      exportable :json, :csv
    end
  end
end
