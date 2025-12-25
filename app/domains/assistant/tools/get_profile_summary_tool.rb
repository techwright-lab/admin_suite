# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: returns a compact profile + pipeline summary for the current user.
    class GetProfileSummaryTool < BaseTool
      def call(args:, tool_execution:)
        limit = (args["top_skills_limit"] || args[:top_skills_limit] || 10).to_i.clamp(1, 25)

        {
          success: true,
          data: {
            user: {
              id: user.id,
              name: user.name,
              email_address: user.email_address,
              years_of_experience: user.years_of_experience,
              current_company: user.current_company&.name,
              current_job_role: user.current_job_role&.title
            },
            target_lists: {
              companies_count: user.target_companies.count,
              job_roles_count: user.target_job_roles.count
            },
            pipeline: {
              active_applications_count: user.interview_applications.where(status: "active").count,
              applications_by_stage: user.interview_applications.group(:pipeline_stage).count
            },
            top_skills: user.top_skills(limit: limit).includes(:skill_tag).map { |us|
              {
                skill: us.skill_tag&.name,
                aggregated_level: us.aggregated_level,
                category: us.category
              }
            }
          }
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end
end
