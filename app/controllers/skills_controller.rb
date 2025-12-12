# frozen_string_literal: true

# Controller for the Skills Dashboard
#
# Provides a comprehensive view of the user's skill profile aggregated
# across all resumes with visualizations and insights.
class SkillsController < ApplicationController
  # GET /skills
  #
  # Main skills dashboard with aggregated skill profile
  def index
    @user_skills = Current.user.user_skills
      .includes(:skill_tag)
      .by_level_desc

    @skills_by_category = @user_skills.group_by(&:category)
    @top_skills = UserSkill.top_skills(Current.user, limit: 10)
    @development_areas = UserSkill.development_areas(Current.user, limit: 5)
    @skill_stats = calculate_skill_stats
    @category_stats = calculate_category_stats
    @resume_coverage = calculate_resume_coverage
  end

  private

  # Calculates overall skill statistics
  #
  # @return [Hash] Skill stats
  def calculate_skill_stats
    skills = Current.user.user_skills

    {
      total: skills.count,
      strong: skills.strong_skills.count,
      moderate: skills.moderate_skills.count,
      developing: skills.developing_skills.count,
      average_level: skills.average(:aggregated_level)&.round(1) || 0,
      most_demonstrated: skills.most_demonstrated.first
    }
  end

  # Calculates stats by category
  #
  # @return [Array<Hash>] Category stats sorted by count
  def calculate_category_stats
    Current.user.user_skills
      .group(:category)
      .select("category, COUNT(*) as count, AVG(aggregated_level) as avg_level")
      .order("count DESC")
      .map do |row|
        {
          category: row.category || "Other",
          count: row.count,
          avg_level: row.avg_level&.round(1) || 0
        }
      end
  end

  # Calculates resume coverage for skills
  #
  # @return [Hash] Resume coverage data
  def calculate_resume_coverage
    resumes = Current.user.user_resumes.analyzed
    total_resumes = resumes.count

    {
      total_resumes: total_resumes,
      resumes_with_skills: resumes.joins(:resume_skills).distinct.count,
      avg_skills_per_resume: total_resumes > 0 ? (ResumeSkill.joins(:user_resume).where(user_resumes: { user_id: Current.user.id }).count.to_f / total_resumes).round(1) : 0
    }
  end
end

