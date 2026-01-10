# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: get details of a specific work experience.
    class GetWorkExperienceTool < BaseTool
      def call(args:, tool_execution:)
        experience_id = (args["experience_id"] || args[:experience_id]).to_i

        if experience_id.zero?
          return { success: false, error: "experience_id is required" }
        end

        experience = user.user_work_experiences.find_by(id: experience_id)

        if experience.nil?
          return { success: false, error: "Work experience not found" }
        end

        {
          success: true,
          data: format_experience_detail(experience)
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def format_experience_detail(exp)
        {
          id: exp.id,
          company: {
            name: exp.display_company_name,
            id: exp.company_id
          },
          role: {
            title: exp.display_role_title,
            id: exp.job_role_id
          },
          start_date: exp.start_date&.to_s,
          end_date: exp.end_date&.to_s,
          is_current: exp.current?,
          duration_months: calculate_duration_months(exp),
          highlights: Array(exp.highlights),
          responsibilities: Array(exp.responsibilities),
          skills: exp.skill_tags.pluck(:name),
          source_type: exp.source_type,
          source_count: exp.source_count,
          created_at: exp.created_at&.iso8601,
          updated_at: exp.updated_at&.iso8601
        }.compact
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
