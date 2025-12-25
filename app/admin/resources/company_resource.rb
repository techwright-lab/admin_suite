# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Company admin management
    #
    # Provides CRUD operations with search, filtering, and merge functionality.
    class CompanyResource < Admin::Base::Resource
      model Company
      portal :ops
      section :content

      index do
        searchable :name, :website
        sortable :name, :created_at, default: :name
        paginate 30

        stats do
          stat :total, -> { Company.count }
          stat :with_website, -> { Company.where.not(website: [ nil, "" ]).count }, color: :blue
          stat :with_logo, -> { Company.where.not(logo_url: [ nil, "" ]).count }, color: :green
          stat :with_job_listings, -> { Company.joins(:job_listings).distinct.count }, color: :amber
        end

        columns do
          column :name, header: "Company"
          column :website
          column :job_listings_count, ->(c) { c.job_listings.count }, header: "Jobs"
          column :applications_count, ->(c) { c.interview_applications.count }, header: "Apps"
        end

        filters do
          filter :sort, type: :select, options: [
            [ "Name (A-Z)", "name" ],
            [ "Recently Added", "recent" ]
          ]
          filter :has_website, type: :toggle, label: "Has Website"
        end
      end

      form do
        field :name, required: true, placeholder: "Company name"
        field :website, type: :url, placeholder: "https://example.com"
        field :about, type: :textarea, rows: 4, help: "Brief description of the company"
        field :logo_url, type: :url, label: "Logo URL", help: "URL to company logo image"
      end

      show do
        sidebar do
          panel :info, title: "Company Info", fields: [ :website, :logo_url ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at, :updated_at ]
        end
        
        main do
          panel :about, title: "About", fields: [ :about ]
          panel :job_listings, title: "Job Listings", 
                association: :job_listings, 
                limit: 10, 
                display: :table,
                columns: [:title, :status, :remote_type, :created_at],
                link_to: :internal_developer_ops_job_listing_path
          panel :applications, title: "Interview Applications", 
                association: :interview_applications, 
                limit: 10, 
                display: :table,
                columns: [:status, :job_listing, :user, :created_at],
                link_to: :internal_developer_ops_interview_application_path
        end
      end

      actions do
        action :disable, method: :post, confirm: "Disable this company?", unless: ->(c) { c.disabled? }
        action :enable, method: :post, if: ->(c) { c.disabled? }
        action :merge, type: :modal
        bulk_action :bulk_disable, label: "Disable Selected"
      end

      exportable :json, :csv
    end
  end
end

