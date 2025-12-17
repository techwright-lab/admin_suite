# frozen_string_literal: true

# Background job for analyzing uploaded resumes with AI skill extraction
#
# Runs the complete analysis pipeline: text extraction -> AI analysis -> skill creation
#
# @example
#   AnalyzeResumeJob.perform_later(user_resume)
#
class AnalyzeResumeJob < ApplicationJob
  queue_as :default

  # Retry on transient failures (API timeouts, rate limits, etc.)
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry on permanent failures
  discard_on ActiveRecord::RecordNotFound

  # Analyze the resume and extract skills
  #
  # @param user_resume [UserResume] The resume to analyze
  # @return [void]
  def perform(user_resume)
    # Skip if already analyzed
    if user_resume.analyzed?
      Rails.logger.info("Resume #{user_resume.id} already analyzed, skipping")
      return
    end

    # Skip if currently processing (prevent duplicate jobs)
    if user_resume.analyzing?
      Rails.logger.info("Resume #{user_resume.id} already processing, skipping")
      return
    end

    Rails.logger.info("Starting analysis for resume #{user_resume.id}: #{user_resume.name}")

    result = Resumes::AnalysisService.new(user_resume).run

    if result[:success]
      Rails.logger.info(
        "Successfully analyzed resume #{user_resume.id}: " \
        "#{result[:skills_count]} skills extracted using #{result[:provider]}"
      )

      # Recompute fit scores since the user's skill profile may have changed.
      RecomputeFitAssessmentsForUserJob.perform_later(user_resume.user_id)
    else
      Rails.logger.error("Failed to analyze resume #{user_resume.id}: #{result[:error]}")
    end
  end
end
