# frozen_string_literal: true

module Admin
  # Controller for managing job listings in the admin panel
  #
  # Provides full CRUD for job listings with extraction status visibility
  class JobListingsController < BaseController
    include Concerns::Paginatable
    include Concerns::Filterable
    include Concerns::StatsCalculator

    PER_PAGE = 25

    before_action :set_job_listing, only: [ :show, :edit, :update, :destroy ]

    # GET /admin/job_listings
    def index
      @pagy, @job_listings = paginate(filtered_listings)
      @stats = calculate_stats
      @filters = filter_params
    end

    # GET /admin/job_listings/:id
    def show
      @scraping_attempts = @job_listing.scraping_attempts.recent.limit(5)
      @latest_attempt = @scraping_attempts.first
      @html_scraping_log = @latest_attempt&.html_scraping_log
      @llm_api_logs = @job_listing.llm_api_logs.order(created_at: :desc).limit(5)
    end

    # GET /admin/job_listings/:id/edit
    def edit
    end

    # PATCH/PUT /admin/job_listings/:id
    def update
      if @job_listing.update(job_listing_params)
        redirect_to admin_job_listing_path(@job_listing), notice: "Job listing updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/job_listings/:id
    def destroy
      @job_listing.destroy
      redirect_to admin_job_listings_path, notice: "Job listing deleted.", status: :see_other
    end

    private

    # Sets the job listing from params
    def set_job_listing
      @job_listing = JobListing.includes(:company, :job_role, :scraping_attempts).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_job_listings_path, alert: "Job listing not found"
    end

    # Returns filtered listings based on params
    #
    # @return [ActiveRecord::Relation] Filtered listings
    def filtered_listings
      listings = JobListing.includes(:company, :job_role).recent

      listings = listings.where(status: params[:status]) if params[:status].present?
      listings = listings.where(remote_type: params[:remote_type]) if params[:remote_type].present?
      listings = listings.joins(:company).where(companies: { id: params[:company_id] }) if params[:company_id].present?

      if params[:search].present?
        search_term = "%#{params[:search]}%"
        listings = listings.joins(:company, :job_role).where(
          "job_listings.title ILIKE :q OR companies.name ILIKE :q OR job_roles.title ILIKE :q",
          q: search_term
        )
      end

      if params[:extraction_status].present?
        case params[:extraction_status]
        when "pending"
          listings = listings.where("scraped_data->>'status' IS NULL OR scraped_data->>'status' = 'pending'")
        when "completed"
          listings = listings.where("scraped_data->>'status' = 'completed'")
        when "failed"
          listings = listings.where("scraped_data->>'status' = 'failed'")
        end
      end

      listings
    end

    # Calculates quick stats
    #
    # @return [Hash] Stats
    def calculate_stats
      base = JobListing.all

      {
        total: base.count,
        by_status: base.group(:status).count,
        by_remote: base.group(:remote_type).count,
        with_description: base.where.not(description: [ nil, "" ]).count,
        with_requirements: base.where.not(requirements: [ nil, "" ]).count
      }
    end

    # Returns the current filter params
    #
    # @return [Hash] Filter params
    def filter_params
      params.permit(:status, :remote_type, :company_id, :search, :extraction_status, :page)
    end

    # Strong params for job listing
    #
    # @return [ActionController::Parameters] Permitted params
    def job_listing_params
      params.require(:job_listing).permit(
        :title, :description, :requirements, :responsibilities,
        :benefits, :perks, :equity_info, :location, :remote_type,
        :salary_min, :salary_max, :salary_currency, :status, :url
      )
    end
  end
end
