# frozen_string_literal: true

module Resumes
  # Service for aggregating skills from multiple resumes into a unified user profile
  #
  # Uses weighted averaging based on:
  # - Recency: Newer resumes have higher weight
  # - Purpose: Role-specific resumes get slightly higher weight
  # - User confirmation: User-adjusted levels take precedence
  #
  # @example
  #   service = Resumes::SkillAggregationService.new(user)
  #   service.aggregate_all  # Recompute all skills
  #   service.aggregate_skill(ruby_skill)  # Recompute single skill
  #
  class SkillAggregationService
    # Weight multipliers
    RECENCY_WEIGHTS = {
      current_year: 1.0,
      last_year: 0.8,
      older: 0.6
    }.freeze

    PURPOSE_WEIGHTS = {
      role_specific: 1.1,
      company_specific: 1.0,
      generic: 0.9
    }.freeze

    attr_reader :user

    # Initialize the service
    #
    # @param user [User] The user to aggregate skills for
    def initialize(user)
      @user = user
    end

    # Aggregates all skills from all resumes
    #
    # @return [Array<UserSkill>] Updated user skills
    def aggregate_all
      # Get all unique skill_tag_ids from user's resumes
      skill_tag_ids = ResumeSkill
        .joins(:user_resume)
        .where(user_resumes: { user_id: user.id })
        .distinct
        .pluck(:skill_tag_id)

      skill_tag_ids.map do |skill_tag_id|
        skill_tag = SkillTag.find(skill_tag_id)
        aggregate_skill(skill_tag)
      end.compact
    end

    # Aggregates a single skill across all resumes
    #
    # @param skill_tag [SkillTag] The skill to aggregate
    # @return [UserSkill, nil] The updated user skill or nil if no data
    def aggregate_skill(skill_tag)
      resume_skills = fetch_resume_skills(skill_tag)

      if resume_skills.empty?
        # Remove user skill if no resume skills exist
        user.user_skills.find_by(skill_tag: skill_tag)&.destroy
        return nil
      end

      latest_by_resume_id = latest_demonstrated_dates_by_resume_id(skill_tag)
      aggregated_data = compute_aggregated_data(resume_skills, latest_by_resume_id: latest_by_resume_id)

      user_skill = user.user_skills.find_or_initialize_by(skill_tag: skill_tag)
      user_skill.update!(
        aggregated_level: aggregated_data[:level],
        confidence_score: aggregated_data[:confidence],
        category: aggregated_data[:category],
        resume_count: resume_skills.size,
        max_years_experience: aggregated_data[:max_years],
        last_demonstrated_at: aggregated_data[:last_demonstrated_at]
      )

      user_skill
    end

    # Removes skills that no longer have any resume_skills
    #
    # @return [Integer] Number of skills removed
    def cleanup_orphaned_skills
      orphaned = user.user_skills.left_outer_joins(:skill_tag)
        .joins("LEFT OUTER JOIN resume_skills ON resume_skills.skill_tag_id = user_skills.skill_tag_id
                AND resume_skills.user_resume_id IN (SELECT id FROM user_resumes WHERE user_id = #{user.id})")
        .where(resume_skills: { id: nil })

      count = orphaned.count
      orphaned.destroy_all
      count
    end

    private

    # Fetches all resume skills for a given skill tag
    #
    # @param skill_tag [SkillTag] The skill tag
    # @return [Array<ResumeSkill>] Resume skills with resume data
    def fetch_resume_skills(skill_tag)
      ResumeSkill
        .includes(:user_resume)
        .joins(:user_resume)
        .where(skill_tag: skill_tag, user_resumes: { user_id: user.id })
        .to_a
    end

    # Computes aggregated data from resume skills
    #
    # @param resume_skills [Array<ResumeSkill>] Resume skills to aggregate
    # @return [Hash] Aggregated data
    def compute_aggregated_data(resume_skills, latest_by_resume_id:)
      weighted_levels = []
      weighted_confidences = []
      categories = Hash.new(0)
      max_years = nil
      last_demonstrated = nil

      resume_skills.each do |rs|
        resume = rs.user_resume
        weight = calculate_weight(resume)

        # Use user_level if set, otherwise model_level
        level = rs.effective_level
        confidence = rs.confidence_score || 0.5

        weighted_levels << { value: level, weight: weight }
        weighted_confidences << { value: confidence, weight: weight }
        categories[rs.category] += weight if rs.category.present?

        # Track max years
        max_years = [ max_years || 0, rs.years_of_experience || 0 ].max

        # Track most recent demonstrated date for this skill (prefer work experience dates).
        demonstrated_on =
          latest_by_resume_id[resume.id] ||
          resume.resume_updated_at ||
          resume.created_at&.to_date
        last_demonstrated = [ last_demonstrated, demonstrated_on ].compact.max
      end

      {
        level: weighted_average(weighted_levels),
        confidence: weighted_average(weighted_confidences),
        category: categories.max_by { |_, v| v }&.first || "Other",
        max_years: max_years.positive? ? max_years : nil,
        last_demonstrated_at: last_demonstrated&.to_time&.in_time_zone
      }
    end

    # Builds a map of user_resume_id => latest demonstrated Date for a given skill_tag,
    # based on extracted work experience dates (best-effort).
    #
    # @param skill_tag [SkillTag]
    # @return [Hash{Integer => Date}]
    def latest_demonstrated_dates_by_resume_id(skill_tag)
      rows = ResumeWorkExperienceSkill
        .joins(resume_work_experience: :user_resume)
        .where(skill_tag_id: skill_tag.id, user_resumes: { user_id: user.id })
        .group("resume_work_experiences.user_resume_id")
        .pluck(
          Arel.sql("resume_work_experiences.user_resume_id"),
          Arel.sql("MAX(CASE WHEN resume_work_experiences.current THEN CURRENT_DATE ELSE COALESCE(resume_work_experiences.end_date, resume_work_experiences.start_date) END)")
        )

      rows.to_h
    rescue StandardError
      {}
    end

    # Calculates weight for a resume based on recency and purpose
    #
    # @param resume [UserResume] The resume
    # @return [Float] Weight multiplier
    def calculate_weight(resume)
      recency_weight = calculate_recency_weight(resume.created_at)
      purpose_weight = PURPOSE_WEIGHTS[resume.purpose.to_sym] || 1.0

      recency_weight * purpose_weight
    end

    # Calculates recency weight based on resume age
    #
    # @param created_at [DateTime] Resume creation date
    # @return [Float] Recency weight
    def calculate_recency_weight(created_at)
      age_in_years = (Time.current - created_at) / 1.year

      if age_in_years < 1
        RECENCY_WEIGHTS[:current_year]
      elsif age_in_years < 2
        RECENCY_WEIGHTS[:last_year]
      else
        RECENCY_WEIGHTS[:older]
      end
    end

    # Computes weighted average
    #
    # @param items [Array<Hash>] Array of {value:, weight:} hashes
    # @return [Float] Weighted average
    def weighted_average(items)
      return 0.0 if items.empty?

      total_weight = items.sum { |i| i[:weight] }
      return 0.0 if total_weight.zero?

      weighted_sum = items.sum { |i| i[:value] * i[:weight] }
      (weighted_sum / total_weight).round(2)
    end
  end
end
