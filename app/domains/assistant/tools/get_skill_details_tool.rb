# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: get detailed information about a specific skill.
    class GetSkillDetailsTool < BaseTool
      def call(args:, tool_execution:)
        skill_id = (args["skill_id"] || args[:skill_id]).to_i
        skill_name = (args["skill_name"] || args[:skill_name]).to_s.strip

        user_skill = find_skill(skill_id, skill_name)

        if user_skill.nil?
          return { success: false, error: "Skill not found in your profile" }
        end

        {
          success: true,
          data: format_skill_detail(user_skill)
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def find_skill(skill_id, skill_name)
        if skill_id.positive?
          skill = user.user_skills.find_by(id: skill_id)
          return skill if skill
        end

        return nil if skill_name.blank?

        user.user_skills
          .joins(:skill_tag)
          .where("lower(skill_tags.name) = ?", skill_name.downcase)
          .first
      end

      def format_skill_detail(user_skill)
        {
          id: user_skill.id,
          skill: {
            id: user_skill.skill_tag_id,
            name: user_skill.skill_tag&.name
          },
          category: user_skill.category,
          proficiency: {
            level: user_skill.aggregated_level&.round(2),
            label: user_skill.proficiency_label,
            is_strong: user_skill.strong?,
            is_developing: user_skill.developing?
          },
          evidence: {
            resume_count: user_skill.resume_count,
            confidence: user_skill.confidence_score&.round(2),
            confidence_percentage: user_skill.confidence_percentage,
            last_demonstrated_at: user_skill.last_demonstrated_at&.to_s,
            max_years_experience: user_skill.max_years_experience
          }.compact,
          work_experiences: skill_work_experiences(user_skill),
          source_resumes: source_resume_names(user_skill)
        }.compact
      end

      def skill_work_experiences(user_skill)
        # Find work experiences where this skill was used
        user.user_work_experiences
          .joins(:skill_tags)
          .where(skill_tags: { id: user_skill.skill_tag_id })
          .reverse_chronological
          .limit(5)
          .map do |exp|
            {
              company: exp.display_company_name,
              role: exp.display_role_title,
              dates: [ exp.start_date&.to_s, exp.end_date&.to_s ].compact.join(" - "),
              is_current: exp.current?
            }.compact
          end
      end

      def source_resume_names(user_skill)
        user_skill.source_resumes.limit(5).map do |resume|
          {
            id: resume.id,
            name: resume.name,
            analyzed_at: resume.analyzed_at&.iso8601
          }
        end
      end
    end
  end
end
