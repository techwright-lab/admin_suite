# frozen_string_literal: true

# Controller for managing Saved Jobs (bookmarked job leads).
#
# Supports saving from an Opportunity or from a pasted URL, and converting a saved job
# into an InterviewApplication using existing services.
class SavedJobsController < ApplicationController
  before_action :set_saved_job, only: [ :destroy, :convert ]
  before_action :set_saved_job_any_status, only: [ :restore ]

  # GET /saved_jobs
  def index
    @saved_jobs = Current.user.saved_jobs.active
      .includes(:opportunity, :fit_assessment)
      .recent
  end

  # POST /saved_jobs
  def create
    @saved_job = build_saved_job_from_params

    if @saved_job.save
      redirect_back fallback_location: saved_jobs_path, notice: "Saved."
    else
      redirect_back fallback_location: saved_jobs_path, alert: @saved_job.errors.full_messages.to_sentence
    end
  end

  # DELETE /saved_jobs/:id
  def destroy
    if @saved_job.archive_removed!
      redirect_back fallback_location: saved_jobs_path, notice: "Removed."
    else
      redirect_back fallback_location: saved_jobs_path, alert: "Could not remove."
    end
  end

  # POST /saved_jobs/:id/restore
  def restore
    if @saved_job.restore!
      redirect_back fallback_location: saved_jobs_path, notice: "Restored."
    else
      redirect_back fallback_location: saved_jobs_path, alert: "Could not restore."
    end
  end

  # POST /saved_jobs/:id/convert
  def convert
    result = convert_saved_job(@saved_job)

    if result[:success]
      @saved_job.update!(converted_at: Time.current) if @saved_job.converted_at.blank?
      redirect_to result[:application], notice: "Application created."
    else
      redirect_back fallback_location: saved_jobs_path, alert: result[:error] || "Could not convert saved job."
    end
  end

  private

  def set_saved_job
    @saved_job = Current.user.saved_jobs.active.find(params[:id])
  end

  def set_saved_job_any_status
    @saved_job = Current.user.saved_jobs.find(params[:id])
  end

  def saved_job_params
    params.expect(saved_job: [ :url, :notes, :opportunity_id ])
  end

  def build_saved_job_from_params
    attrs = saved_job_params

    if attrs[:opportunity_id].present?
      opportunity = Current.user.opportunities.find(attrs[:opportunity_id])
      Current.user.saved_jobs.new(
        opportunity: opportunity,
        url: nil,
        company_name: opportunity.company_name,
        job_role_title: opportunity.job_role_title,
        title: opportunity.job_role_title,
        notes: attrs[:notes]
      )
    else
      Current.user.saved_jobs.new(
        url: attrs[:url]&.strip,
        notes: attrs[:notes]
      )
    end
  end

  def convert_saved_job(saved_job)
    if saved_job.opportunity.present?
      Opportunities::CreateApplicationService.new(saved_job.opportunity, Current.user).call
    else
      url = saved_job.effective_url
      return { success: false, error: "URL is missing" } if url.blank?

      QuickApplyFromUrlService.new(url, Current.user).call
    end
  end
end
