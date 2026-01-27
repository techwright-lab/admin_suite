# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Job Listing admin management
    #
    # Provides CRUD operations with extraction status visibility and company/role filtering.
    class JobListingResource < Admin::Base::Resource
      model JobListing
      portal :ops
      section :jobs

      index do
        searchable :title
        sortable :title, :created_at, :status, default: :created_at
        paginate 25

        stats do
          stat :total, -> { JobListing.count }
          stat :active, -> { JobListing.where(status: "active").count }, color: :green
          stat :closed, -> { JobListing.where(status: "closed").count }, color: :slate
          stat :with_description, -> { JobListing.where.not(description: [ nil, "" ]).count }, color: :blue
        end

        columns do
          column :title
          column :company, ->(jl) { jl.company&.name }
          column :job_role, ->(jl) { jl.job_role&.title }
          column :status, type: :label, label_color: ->(jl) {
            case jl.status.to_sym
            when :active then :green
            when :closed then :slate
            when :draft then :slate
            else :gray
            end
          }
          column :remote_type
          column :created_at, ->(jl) { jl.created_at.strftime("%b %d, %Y") }
        end

        filters do
          filter :status, type: :select, options: [
            [ "All Statuses", "" ],
            [ "Active", "active" ],
            [ "Closed", "closed" ],
            [ "Draft", "draft" ]
          ]
          filter :remote_type, type: :select, label: "Remote", options: [
            [ "All Types", "" ],
            [ "Remote", "remote" ],
            [ "Hybrid", "hybrid" ],
            [ "On-site", "onsite" ]
          ]
          filter :sort, type: :select, options: [
            [ "Recently Added", "recent" ],
            [ "Title (A-Z)", "title" ],
            [ "Status", "status" ]
          ]
        end
      end

      form do
        section "Basic Information" do
          field :title, required: true
          field :url, type: :url, label: "Listing URL"

          row cols: 2 do
            field :status, type: :select, collection: [
              [ "Active", "active" ],
              [ "Closed", "closed" ],
              [ "Draft", "draft" ]
            ]
            field :remote_type, type: :select, collection: [
              [ "Remote", "remote" ],
              [ "Hybrid", "hybrid" ],
              [ "On-site", "onsite" ]
            ]
          end
        end

        section "Content" do
          field :description, type: :textarea, rows: 6
          field :requirements, type: :textarea, rows: 4
          field :responsibilities, type: :textarea, rows: 4
          field :benefits, type: :textarea, rows: 3
        end

        section "Compensation" do
          row cols: 3 do
            field :salary_min, type: :number, label: "Min Salary"
            field :salary_max, type: :number, label: "Max Salary"
            field :salary_currency, type: :select, collection: [
              [ "USD", "USD" ],
              [ "EUR", "EUR" ],
              [ "GBP", "GBP" ]
            ]
          end
          field :location
        end
      end

      show do
        sidebar do
          panel :status, title: "Status", fields: [ :status, :remote_type ]
          panel :salary, title: "Compensation", fields: [ :salary_min, :salary_max, :salary_currency, :location ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at, :updated_at ]
        end

        main do
          panel :info, title: "Listing Info", fields: [ :title, :url ]
          panel :content, title: "Description", fields: [ :description ]
          panel :requirements, title: "Requirements", fields: [ :requirements, :responsibilities ]
          panel :benefits, title: "Benefits", fields: [ :benefits ]
          panel :scraping, title: "Scraping Attempts", association: :scraping_attempts, limit: 5, display: :list
        end
      end

      actions do
        action :disable, method: :post, confirm: "Disable this job listing?", unless: ->(jl) { jl.status == "closed" }
        action :enable, method: :post, if: ->(jl) { jl.status == "closed" }
      end

      exportable :json, :csv
    end
  end
end
