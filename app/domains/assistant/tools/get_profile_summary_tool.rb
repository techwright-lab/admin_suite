# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: returns a compact profile + pipeline summary for the current user.
    # Includes career context (work history, resume summary, target domains).
    # NOTE: Does not expose email_address to the LLM for privacy.
    class GetProfileSummaryTool < BaseTool
      def call(args:, tool_execution:)
        skills_limit = (args["top_skills_limit"] || args[:top_skills_limit] || 10).to_i.clamp(1, 25)
        work_history_limit = (args["work_history_limit"] || args[:work_history_limit] || 5).to_i.clamp(1, 10)

        {
          success: true,
          data: {
            user: build_user_data,
            career: build_career_data(work_history_limit),
            target_lists: build_target_lists,
            pipeline: build_pipeline_data,
            top_skills: build_top_skills(skills_limit)
          }
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def build_user_data
        {
          id: user.id,
          name: user.name,
          years_of_experience: user.years_of_experience,
          current_company: user.current_company&.name,
          current_job_role: user.current_job_role&.title,
          bio: user.bio.presence,
          social_profiles: {
            linkedin: user.linkedin_url.presence,
            github: user.github_url.presence,
            twitter: user.twitter_url.presence,
            portfolio: user.portfolio_url.presence,
            gitlab: user.gitlab_url.presence
          }.compact
        }.compact
      end

      def build_career_data(work_history_limit)
        resume = user.user_resumes.analyzed.recent_first.first

        {
          resume_summary: resume&.analysis_summary,
          strengths: Array(resume&.strengths).first(5),
          domains: Array(resume&.domains).first(5),
          work_history: build_work_history(work_history_limit)
        }.compact
      end

      def build_work_history(limit)
        user.user_work_experiences
          .reverse_chronological
          .limit(limit)
          .map do |exp|
            {
              id: exp.id,
              company: exp.display_company_name,
              role: exp.display_role_title,
              start_date: exp.start_date&.to_s,
              end_date: exp.end_date&.to_s,
              is_current: exp.current?,
              highlights: Array(exp.highlights).first(3),
              skills: exp.skill_tags.pluck(:name).first(5)
            }.compact
          end
      end

      def build_target_lists
        {
          companies_count: user.target_companies.count,
          companies: user.target_companies.limit(5).pluck(:name),
          job_roles_count: user.target_job_roles.count,
          job_roles: user.target_job_roles.limit(5).pluck(:title),
          domains_count: user.target_domains.count,
          domains: user.target_domains.limit(5).pluck(:name)
        }
      end

      def build_pipeline_data
        {
          active_applications_count: user.interview_applications.where(status: "active").count,
          applications_by_stage: user.interview_applications.group(:pipeline_stage).count
        }
      end

      def build_top_skills(limit)
        user.top_skills(limit: limit).includes(:skill_tag).map do |us|
          {
            skill: us.skill_tag&.name,
            aggregated_level: us.aggregated_level&.round(2),
            category: us.category
          }.compact
        end
      end
    end
  end
end
