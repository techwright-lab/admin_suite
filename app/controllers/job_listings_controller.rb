# frozen_string_literal: true

# Controller for managing job listings
class JobListingsController < ApplicationController
  before_action :set_job_listing, only: [:show, :edit, :update, :destroy]

  # GET /job_listings
  def index
    @job_listings = JobListing.includes(:company, :job_role).recent

    if params[:company_id].present?
      @job_listings = @job_listings.where(company_id: params[:company_id])
    end

    if params[:job_role_id].present?
      @job_listings = @job_listings.where(job_role_id: params[:job_role_id])
    end

    if params[:remote_type].present?
      @job_listings = @job_listings.where(remote_type: params[:remote_type])
    end

    if params[:status].present?
      @job_listings = @job_listings.where(status: params[:status])
    else
      @job_listings = @job_listings.active
    end

    respond_to do |format|
      format.html
      format.json { render json: @job_listings }
    end
  end

  # GET /job_listings/:id
  def show
    @applications = @job_listing.interview_applications.includes(:user).recent
  end

  # GET /job_listings/new
  def new
    @job_listing = JobListing.new
    @companies = Company.alphabetical.limit(100)
    @job_roles = JobRole.alphabetical.limit(100)
  end

  # GET /job_listings/:id/edit
  def edit
    @companies = Company.alphabetical.limit(100)
    @job_roles = JobRole.alphabetical.limit(100)
  end

  # POST /job_listings
  def create
    @job_listing = JobListing.new(job_listing_params)
    process_custom_sections(@job_listing)

    if @job_listing.save
      respond_to do |format|
        format.html { redirect_to @job_listing, notice: "Job listing created successfully!" }
        format.turbo_stream { flash.now[:notice] = "Job listing created successfully!" }
      end
    else
      @companies = Company.alphabetical.limit(100)
      @job_roles = JobRole.alphabetical.limit(100)
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /job_listings/:id
  def update
    @job_listing.assign_attributes(job_listing_params)
    process_custom_sections(@job_listing)
    
    if @job_listing.save
      respond_to do |format|
        format.html { redirect_to @job_listing, notice: "Job listing updated successfully!" }
        format.turbo_stream { flash.now[:notice] = "Job listing updated successfully!" }
      end
    else
      @companies = Company.alphabetical.limit(100)
      @job_roles = JobRole.alphabetical.limit(100)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /job_listings/:id
  def destroy
    @job_listing.destroy

    respond_to do |format|
      format.html { redirect_to job_listings_path, notice: "Job listing deleted successfully!", status: :see_other }
      format.turbo_stream { flash.now[:notice] = "Job listing deleted successfully!" }
    end
  end

  private

  def set_job_listing
    @job_listing = JobListing.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to job_listings_path, alert: "Job listing not found"
  end

  def job_listing_params
    params.expect(job_listing: [
      :company_id,
      :job_role_id,
      :title,
      :url,
      :source_id,
      :job_board_id,
      :description,
      :requirements,
      :responsibilities,
      :salary_min,
      :salary_max,
      :salary_currency,
      :equity_info,
      :benefits,
      :perks,
      :location,
      :remote_type,
      :status,
      custom_sections_keys: [],
      custom_sections_values: [],
      custom_sections: {},
      scraped_data: {}
    ])
  end

  def process_custom_sections(job_listing)
    return unless params[:job_listing]
    
    keys = params[:job_listing][:custom_sections_keys]
    values = params[:job_listing][:custom_sections_values]
    
    if keys.present? && values.present?
      custom_sections = {}
      keys.each_with_index do |key, index|
        next if key.blank?
        custom_sections[key] = values[index] if values[index].present?
      end
      job_listing.custom_sections = custom_sections
    end
  end
end

