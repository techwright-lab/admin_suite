# frozen_string_literal: true

module Assistant
  module Tools
    # Read-only: list the user's skills with proficiency levels.
    class ListSkillsTool < BaseTool
      VALID_FILTERS = %w[strong moderate developing all].freeze

      def call(args:, tool_execution:)
        limit = (args["limit"] || args[:limit] || 25).to_i.clamp(1, 100)
        category = (args["category"] || args[:category]).to_s.presence
        filter = (args["filter"] || args[:filter] || "all").to_s

        skills = build_query(limit, category, filter)

        {
          success: true,
          data: {
            count: skills.size,
            total_count: user.user_skills.count,
            filter_applied: filter,
            category_filter: category,
            skills: skills.map { |us| format_skill(us) },
            categories: user.user_skills.distinct.pluck(:category).compact.sort
          }
        }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def build_query(limit, category, filter)
        base = user.user_skills.includes(:skill_tag)

        # Apply category filter
        base = base.by_category(category) if category.present?

        # Apply proficiency filter
        base = case filter
        when "strong"
          base.strong_skills
        when "moderate"
          base.moderate_skills
        when "developing"
          base.developing_skills
        else
          base
        end

        base.by_level_desc.limit(limit)
      end

      def format_skill(user_skill)
        {
          id: user_skill.id,
          skill_id: user_skill.skill_tag_id,
          name: user_skill.skill_tag&.name,
          category: user_skill.category,
          proficiency_level: user_skill.aggregated_level&.round(2),
          proficiency_label: user_skill.proficiency_label,
          resume_count: user_skill.resume_count,
          confidence: user_skill.confidence_score&.round(2),
          last_demonstrated_at: user_skill.last_demonstrated_at&.to_s,
          is_strong: user_skill.strong?,
          is_developing: user_skill.developing?
        }.compact
      end
    end
  end
end
