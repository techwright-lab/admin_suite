class Avo::Resources::JobListing < Avo::BaseResource
  self.includes = [:company, :job_role, :interview_applications, :scraping_attempts]
  
  self.search = {
    query: -> { query.ransack(title_cont: params[:q], description_cont: params[:q], m: "or").result(distinct: false) }
  }

  def fields
    field :id, as: :id
    
    # Extraction Status Badge
    field :extraction_status_badge, as: :badge, computed: true, only_on: [:index, :show] do
      case record.extraction_status
      when "completed" then { label: "Extracted", color: :success }
      when "failed" then { label: "Failed", color: :danger }
      when "pending" then { label: "Pending", color: :info }
      else { label: "Unknown", color: :neutral }
      end
    end
    
    field :extraction_confidence_pct, as: :text, computed: true, only_on: [:show] do
      confidence = (record.extraction_confidence * 100).round(1)
      "#{confidence}%"
    end
    
    # Basic Information
    field :company, as: :belongs_to, required: true, searchable: true
    field :job_role, as: :belongs_to, required: true, searchable: true
    field :title, as: :text, help: "Override job role title if needed"
    field :url, as: :text, name: "Job URL"
    field :source_id, as: :text, help: "Company's internal job ID"
    field :job_board_id, as: :text, help: "LinkedIn, Indeed, etc. ID"
    field :status, as: :select, enum: ::JobListing.statuses, required: true
    
    # Location
    field :location, as: :text
    field :remote_type, as: :select, enum: ::JobListing.remote_types, required: true
    
    # Compensation
    field :salary_min, as: :number, name: "Min Salary"
    field :salary_max, as: :number, name: "Max Salary"
    field :salary_currency, as: :text, default: "USD"
    field :equity_info, as: :textarea
    
    # Job Details
    field :description, as: :textarea
    field :requirements, as: :textarea
    field :responsibilities, as: :textarea
    field :benefits, as: :textarea
    field :perks, as: :textarea
    
    # Custom Data
    field :custom_sections, as: :code, language: "json", help: "Custom sections as JSON"
    field :scraped_data, as: :code, language: "json", help: "Scraped data as JSON"
    
    # Associations
    field :interview_applications, as: :has_many
    field :scraping_attempts, as: :has_many
    
    # Timestamps
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end
  
  def filters
    filter Avo::Filters::JobListingStatusFilter
    filter Avo::Filters::JobListingRemoteTypeFilter
    filter ExtractionStatusFilter
  end
  
  def actions
    action Avo::Actions::ReExtractJobListing
    action Avo::Actions::MarkJobListingAsVerified
  end
  
  # Extraction status filter
  class ExtractionStatusFilter < Avo::Filters::SelectFilter
    self.name = "Extraction Status"
    
    def apply(request, query, value)
      case value
      when "needs_review"
        # Get IDs of job listings that need review
        ids = query.select { |jl| jl.extraction_needs_review? }.map(&:id)
        query.where(id: ids)
      when "completed"
        query.where("scraped_data->>'status' = ?", "completed")
      when "pending"
        query.where("scraped_data->>'status' IS NULL OR scraped_data->>'status' = ?", "pending")
      else
        query
      end
    end
    
    def options
      [
        ["Completed", "completed"],
        ["Pending", "pending"],
        ["Needs Review", "needs_review"]
      ]
    end
  end
end
