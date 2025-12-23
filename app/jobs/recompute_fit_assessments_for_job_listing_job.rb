# frozen_string_literal: true

# Background job to enqueue fit recomputation for items impacted by a job listing update.
class RecomputeFitAssessmentsForJobListingJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  # @param job_listing_id [Integer]
  def perform(job_listing_id)
    job_listing = JobListing.find(job_listing_id)

    InterviewApplication.where(job_listing_id: job_listing.id).find_each do |application|
      ComputeFitAssessmentJob.perform_later(application.user_id, "InterviewApplication", application.id)
    end

    # Saved jobs created from a pasted URL.
    SavedJob.active.where(url: job_listing.url).find_each do |saved_job|
      ComputeFitAssessmentJob.perform_later(saved_job.user_id, "SavedJob", saved_job.id)
    end

    # Opportunities with a matching job URL.
    Opportunity.where(job_url: job_listing.url).find_each do |opportunity|
      ComputeFitAssessmentJob.perform_later(opportunity.user_id, "Opportunity", opportunity.id)
    end
  end
end
