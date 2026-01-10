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
    @skills_by_experience = calculate_skills_by_experience

    @merged_strengths = merged_strengths_for(Current.user)
    @resume_domains = aggregated_label_counts(Current.user.user_resumes.analyzed.pluck(:domains).flatten)
  end

  # GET /skills/:id
  #
  # Skill detail view showing proficiency + evidence of use in work history.
  def show
    @skill_tag = SkillTag.find(params[:id])

    @user_skill = Current.user.user_skills.includes(:skill_tag).find_by(skill_tag_id: @skill_tag.id)

    @experience_skill_rows = UserWorkExperienceSkill
      .includes(:skill_tag, user_work_experience: [ :company, :job_role ])
      .joins(:user_work_experience)
      .where(user_work_experiences: { user_id: Current.user.id }, skill_tag_id: @skill_tag.id)
      .order(Arel.sql("COALESCE(user_work_experiences.end_date, user_work_experiences.start_date) DESC NULLS LAST"), created_at: :desc)

    @resume_sources = UserResume
      .joins(resume_work_experiences: :resume_work_experience_skills)
      .where(user_id: Current.user.id, resume_work_experience_skills: { skill_tag_id: @skill_tag.id })
      .distinct
      .order(created_at: :desc)
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

  # Calculates experience-based usage for skills (skills used in distinct work experiences).
  #
  # @return [Array<Hash>]
  def calculate_skills_by_experience
    rows = UserWorkExperienceSkill
      .joins(user_work_experience: :user)
      .where(user_work_experiences: { user_id: Current.user.id })
      .group(:skill_tag_id)
      .select(
        :skill_tag_id,
        Arel.sql("COUNT(DISTINCT user_work_experience_id) AS experience_count"),
        Arel.sql("MAX(last_used_on) AS last_used_on")
      )
      .order(Arel.sql("experience_count DESC"), Arel.sql("last_used_on DESC NULLS LAST"))
      .limit(12)

    skill_tags = SkillTag.where(id: rows.map(&:skill_tag_id)).index_by(&:id)

    rows.map do |row|
      tag = skill_tags[row.skill_tag_id]
      {
        skill_tag_id: row.skill_tag_id,
        name: tag&.name || "Unknown",
        experience_count: row.try(:experience_count).to_i,
        last_used_on: row.try(:last_used_on)
      }
    end
  end

  def aggregated_label_counts(labels)
    Labels::DedupeService
      .new(labels, similarity_threshold: 0.82, overlap_threshold: 0.75)
      .grouped_counts
  end

  def merged_strengths_for(user)
    resume_counts = aggregated_label_counts(user.user_resumes.analyzed.pluck(:strengths).flatten)

    feedback_strengths = ProfileInsightsService.new(user).generate_insights[:strengths] || []
    feedback_counts = {}
    feedback_strengths.each do |row|
      name = row[:name] || row["name"]
      count = row[:count] || row["count"] || 0
      key = normalize_label_key(name)
      next if key.blank?

      feedback_counts[key] ||= { label: name.to_s.strip, count: 0 }
      feedback_counts[key][:count] += count.to_i
    end

    keys = (resume_counts.keys + feedback_counts.keys).uniq
    merged = keys.map do |key|
      resume = resume_counts[key]
      feedback = feedback_counts[key]

      label = resume&.dig(:label).presence || feedback&.dig(:label).presence || key
      resume_count = resume&.dig(:count).to_i
      feedback_count = feedback&.dig(:count).to_i
      sources = []
      sources << "resume" if resume_count.positive?
      sources << "feedback" if feedback_count.positive?

      {
        key: key,
        label: label,
        total_count: resume_count + feedback_count,
        resume_count: resume_count,
        feedback_count: feedback_count,
        sources: sources
      }
    end

    merged.sort_by { |h| -h[:total_count].to_i }
  end

  def normalize_label_key(label)
    # Kept for backward compatibility (used by merged_strengths_for feedback keys).
    ActiveSupport::Inflector.transliterate(label.to_s)
      .downcase
      .tr("&", "and")
      .gsub(/[^a-z0-9\s]/, " ")
      .gsub(/\s+/, " ")
      .strip
  end
end
