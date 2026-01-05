# frozen_string_literal: true

require "digest"

module InterviewPrep
  # Builds normalized inputs for interview prep generation and computes digests for caching.
  class InputsBuilderService
    ALGORITHM_VERSION = "v1_job_listing_primary"

    # @param user [User]
    # @param interview_application [InterviewApplication]
    def initialize(user:, interview_application:)
      @user = user
      @application = interview_application
    end

    # Returns a hash of inputs used by all prep generators.
    #
    # @return [Hash]
    def build
      {
        algorithm_version: ALGORITHM_VERSION,
        candidate_profile: candidate_profile,
        job_context: job_context,
        interview_stage: interview_stage,
        feedback_themes: feedback_themes
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

    attr_reader :user, :application

    def candidate_profile
      resume = user.user_resumes.analyzed.recent_first.first
      top_skills = user.top_skills(limit: 15).includes(:skill_tag).map do |us|
        {
          skill: us.skill_tag&.name,
          aggregated_level: us.aggregated_level&.round(2),
          category: us.category
        }.compact
      end

      {
        user: {
          id: user.id,
          name: user.name,
          years_of_experience: user.years_of_experience,
          current_company: user.current_company&.name,
          current_job_role: user.current_job_role&.title
        },
        resume: {
          id: resume&.id,
          analyzed_at: resume&.analyzed_at,
          summary: resume&.analysis_summary,
          strengths: Array(resume&.strengths),
          domains: Array(resume&.domains)
        },
        top_skills: top_skills
      }
    end

    # JobListing is the default source of truth.
    # Manual job_description_text is supplemental fallback/extra context.
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
          benefits: jl.benefits,
          perks: jl.perks,
          custom_sections: jl.custom_sections
        }.compact
      else
        {}
      end

      {
        company: application.display_company&.name,
        role: application.display_job_role&.title,
        extracted_job_listing: extracted,
        supplemental_job_text: application.job_description_text.presence
      }.compact
    end

    def interview_stage
      next_round = application.interview_rounds.upcoming.order(scheduled_at: :asc).first
      return next_round.stage.to_s if next_round&.stage.present?

      # Fallback mapping from pipeline stage
      case application.pipeline_stage&.to_sym
      when :screening then "screening"
      when :interviewing then "technical"
      when :offer then "hiring_manager"
      else "screening"
      end
    end

    def feedback_themes
      feedbacks = InterviewFeedback
        .joins(interview_round: { interview_application: :user })
        .where(users: { id: user.id })
        .recent
        .limit(50)

      tags = feedbacks.flat_map(&:tag_list).map(&:to_s).map(&:strip).reject(&:blank?)
      tag_counts = tags.each_with_object(Hash.new(0)) { |t, h| h[t] += 1 }

      {
        top_tags: tag_counts.sort_by { |_k, v| -v }.first(10).map { |k, v| { tag: k, count: v } },
        notes: "Derived from your recent self-reflections (tags only)."
      }
    end
  end
end
