# frozen_string_literal: true

require "digest"

module InterviewRoundPrep
  # Builds normalized inputs for round-specific interview prep generation.
  #
  # Gathers context from:
  # - The interview round (type, stage, scheduled time, interviewer)
  # - The interview application (company, job role, job listing)
  # - User profile and history
  # - Historical performance on similar round types
  # - Company interview patterns
  #
  # @example
  #   service = InterviewRoundPrep::InputsBuilderService.new(interview_round: round)
  #   inputs = service.build
  #   digest = service.digest_for(:comprehensive)
  class InputsBuilderService < ApplicationService
    ALGORITHM_VERSION = "v1_round_prep"

    # @param interview_round [InterviewRound]
    def initialize(interview_round:)
      @round = interview_round
      @application = interview_round.interview_application
      @user = @application.user
    end

    # Returns a hash of inputs used by round prep generators.
    #
    # @return [Hash]
    def build
      {
        algorithm_version: ALGORITHM_VERSION,
        round_context: round_context,
        job_context: job_context,
        candidate_profile: candidate_profile,
        historical_performance: historical_performance,
        company_patterns: company_patterns
      }
    end

    # Computes an idempotency digest for a specific artifact kind.
    #
    # @param kind [String, Symbol]
    # @return [String]
    def digest_for(kind)
      payload = build.merge(kind: kind.to_s)
      Digest::SHA256.hexdigest(JSON.generate(payload))
    end

    private

    attr_reader :round, :application, :user

    # Context about the specific interview round
    #
    # @return [Hash]
    def round_context
      {
        id: round.id,
        stage: round.stage,
        stage_name: round.stage_display_name,
        round_type: round_type_context,
        scheduled_at: round.scheduled_at&.iso8601,
        duration_minutes: round.duration_minutes,
        interviewer: {
          name: round.interviewer_name,
          role: round.interviewer_role
        }.compact.presence,
        notes: round.notes,
        position_in_process: round.position,
        has_video_link: round.has_video_link?
      }.compact
    end

    # Round type information
    #
    # @return [Hash, nil]
    def round_type_context
      return nil unless round.interview_round_type

      {
        name: round.interview_round_type.name,
        slug: round.interview_round_type.slug,
        description: round.interview_round_type.description,
        department: round.interview_round_type.department_name
      }.compact
    end

    # Context about the job application
    #
    # @return [Hash]
    def job_context
      jl = application.job_listing

      extracted = if jl
        {
          title: jl.display_title,
          url: jl.url,
          location: jl.location_display,
          salary_range: jl.salary_range,
          description: jl.description,
          responsibilities: jl.responsibilities,
          requirements: jl.requirements,
          about_company: jl.about_company,
          company_culture: jl.company_culture,
          custom_sections: jl.custom_sections
        }.compact
      else
        {}
      end

      {
        company: application.display_company&.name,
        company_id: application.company_id,
        role: application.display_job_role&.title,
        role_id: application.job_role_id,
        department: application.job_role&.department_name,
        extracted_job_listing: extracted.presence,
        supplemental_job_text: application.job_description_text.presence,
        pipeline_stage: application.pipeline_stage
      }.compact
    end

    # Candidate profile information
    #
    # @return [Hash]
    def candidate_profile
      resume = user.user_resumes.analyzed.recent_first.first
      top_skills = user.top_skills(limit: 10).includes(:skill_tag).map do |us|
        {
          skill: us.skill_tag&.name,
          level: us.aggregated_level&.round(2)
        }.compact
      end

      {
        name: user.name,
        years_of_experience: user.years_of_experience,
        current_role: user.current_job_role&.title,
        current_company: user.current_company&.name,
        resume_summary: resume&.analysis_summary,
        strengths: Array(resume&.strengths).first(5),
        top_skills: top_skills
      }.compact
    end

    # Historical performance on similar round types
    #
    # @return [Hash]
    def historical_performance
      safely(fallback: { note: "Historical data unavailable", error: true }) do
        HistoricalAnalyzerService.new(user: user, round_type: round.interview_round_type).analyze
      end
    end

    # Company-specific interview patterns
    #
    # @return [Hash]
    def company_patterns
      safely(fallback: { note: "Company pattern data unavailable", error: true }) do
        CompanyPatternsService.new(
          company: application.company,
          round_type: round.interview_round_type
        ).analyze
      end
    end
  end
end
