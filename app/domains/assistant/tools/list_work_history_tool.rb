# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: list the user's work history (UserWorkExperience records).
    class ListWorkHistoryTool < BaseTool
      def call(args:, tool_execution:)
        limit = (args["limit"] || args[:limit] || 20).to_i.clamp(1, 50)
        include_skills = args["include_skills"] != false && args[:include_skills] != false

        experiences = user.user_work_experiences
          .reverse_chronological
          .limit(limit)

        experiences = experiences.includes(:skill_tags) if include_skills

        {
          success: true,
          data: {
            count: experiences.size,
            total_count: user.user_work_experiences.count,
            work_history: experiences.map { |exp| format_experience(exp, include_skills) }
          }
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def format_experience(exp, include_skills)
        result = {
          id: exp.id,
          company: exp.display_company_name,
          role: exp.display_role_title,
          start_date: exp.start_date&.to_s,
          end_date: exp.end_date&.to_s,
          is_current: exp.current?,
          duration_months: calculate_duration_months(exp),
          highlights: Array(exp.highlights).first(5),
          responsibilities: Array(exp.responsibilities).first(5),
          source_type: exp.source_type
        }.compact

        if include_skills
          result[:skills] = exp.skill_tags.pluck(:name)
        end

        result
      end

      def calculate_duration_months(exp)
        return nil unless exp.start_date

        end_date = exp.current? ? Date.current : (exp.end_date || Date.current)
        months = ((end_date.year - exp.start_date.year) * 12) + (end_date.month - exp.start_date.month)
        months.clamp(0, 600) # Cap at 50 years
      end
    end
  end
end
