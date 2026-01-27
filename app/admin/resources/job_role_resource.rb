# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for JobRole admin management
    #
    # Provides CRUD operations with search, filtering, and merge functionality.
    class JobRoleResource < Admin::Base::Resource
      model JobRole
      portal :ops
      section :content

      index do
        searchable :title, :description
        sortable :title, :created_at, default: :title
        paginate 30

        stats do
          stat :total, -> { JobRole.count }
          stat :with_listings, -> { JobRole.joins(:job_listings).distinct.count }, color: :blue
          stat :user_targets, -> { JobRole.joins(:user_target_job_roles).distinct.count }, color: :amber
        end

        columns do
          column :title
          column :category, ->(jr) { jr.category&.name }, type: :label, label_color: :blue
          column :job_listings_count, ->(jr) { jr.job_listings.count }, header: "Listings"
          column :applications_count, ->(jr) { jr.interview_applications.count }, header: "Apps"
        end

        filters do
          filter :category_id, type: :select, label: "Category",
                 options: -> { Category.pluck(:name, :id) }
          filter :sort, type: :select, options: [
            [ "Title (A-Z)", "title" ],
            [ "Recently Added", "recent" ]
          ]
        end
      end

      form do
        field :title, required: true, placeholder: "Job role title"
        field :category_id, type: :searchable_select, label: "Category",
              collection: "/admin/categories/autocomplete",
              create_url: "/admin/categories"
        field :description, type: :textarea, rows: 4
      end

      show do
        section :details, fields: [ :title, :description, :created_at, :updated_at ]
        section :category, fields: [ :category ]
        section :job_listings, association: :job_listings, limit: 10
      end

      actions do
        action :disable, method: :post, confirm: "Disable this job role?"
        action :enable, method: :post
        action :merge, type: :modal
        bulk_action :bulk_disable
      end

      exportable :json, :csv
    end
  end
end
