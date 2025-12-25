# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Category admin management
    #
    # Provides CRUD operations with search, filtering, and merge functionality.
    class CategoryResource < Admin::Base::Resource
      model Category
      portal :ops
      section :content

      index do
        searchable :name
        sortable :name, :created_at, default: :name
        paginate 30

        stats do
          stat :total, -> { Category.count }
          stat :with_job_roles, -> { Category.joins(:job_roles).distinct.count }, color: :blue
        end

        columns do
          column :name
          column :job_roles_count, ->(c) { c.job_roles.count }, header: "Job Roles"
        end

        filters do
          filter :sort, type: :select, options: [
            [ "Name (A-Z)", "name" ],
            [ "Recently Added", "recent" ]
          ]
        end
      end

      form do
        field :name, required: true, placeholder: "Category name"
      end

      show do
        sidebar do
          panel :timestamps, title: "Timestamps", fields: [ :created_at, :updated_at ]
        end
        
        main do
          panel :job_roles, title: "Job Roles", association: :job_roles, limit: 20, display: :list
        end
      end

      actions do
        action :disable, method: :post, confirm: "Disable this category?"
        action :enable, method: :post
        action :merge, type: :modal
      end

      exportable :json, :csv
    end
  end
end

