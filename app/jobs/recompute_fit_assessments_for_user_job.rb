# frozen_string_literal: true

# Background job to enqueue fit recomputation for all relevant items for a user.
class RecomputeFitAssessmentsForUserJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  # @param user_id [Integer]
  def perform(user_id)
    user = User.find(user_id)

    user.opportunities.actionable.find_each do |opportunity|
      ComputeFitAssessmentJob.perform_later(user.id, "Opportunity", opportunity.id)
    end

    user.saved_jobs.active.unconverted.find_each do |saved_job|
      ComputeFitAssessmentJob.perform_later(user.id, "SavedJob", saved_job.id)
    end

    user.interview_applications.active.find_each do |application|
      ComputeFitAssessmentJob.perform_later(user.id, "InterviewApplication", application.id)
    end
  end
end
