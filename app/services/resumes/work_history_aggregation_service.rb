# frozen_string_literal: true

module Resumes
  # Aggregates work history across all analyzed resumes into a merged user-level profile.
  class WorkHistoryAggregationService
    # @param user [User]
    def initialize(user)
      @user = user
    end

    # @return [void]
    def run
      ActiveRecord::Base.transaction do
        rebuild_user_work_experiences!
      end
    end

    private

    attr_reader :user

    def rebuild_user_work_experiences!
      # Clear and rebuild for correctness (can be optimized later).
      UserWorkExperience.where(user: user).destroy_all

      resume_experiences = ResumeWorkExperience
        .joins(:user_resume)
        .includes(:company, :job_role, :resume_work_experience_skills, :skill_tags)
        .where(user_resumes: { user_id: user.id, analysis_status: UserResume.analysis_statuses[:completed] })
        .to_a

      groups = resume_experiences.group_by { |rwe| merge_key_for(rwe) }

      groups.each do |key, items|
        next if key.blank?

        merged = build_merged_experience(items)
        uwe = UserWorkExperience.create!(merged.merge(user: user))

        items.each do |rwe|
          UserWorkExperienceSource.create!(user_work_experience: uwe, resume_work_experience: rwe)
        end

        upsert_experience_skills!(uwe, items)
      end
    end

    def merge_key_for(rwe)
      company = rwe.display_company_name.to_s.strip.downcase
      role = rwe.display_role_title.to_s.strip.downcase
      [ company.presence, role.presence ].compact.join("|")
    end

    def build_merged_experience(items)
      first = items.first

      company_name = items.map(&:display_company_name).map { |s| s.to_s.strip }.reject(&:blank?).first
      role_title = items.map(&:display_role_title).map { |s| s.to_s.strip }.reject(&:blank?).first

      start_date = items.map(&:start_date).compact.min
      end_date = items.map(&:end_date).compact.max
      current = items.any?(&:current)

      responsibilities = items.flat_map { |i| Array(i.responsibilities) }.map { |s| s.to_s.strip }.reject(&:blank?).uniq.first(50)
      highlights = items.flat_map { |i| Array(i.highlights) }.map { |s| s.to_s.strip }.reject(&:blank?).uniq.first(50)

      {
        company: first.company,
        job_role: first.job_role,
        company_name: company_name,
        role_title: role_title,
        start_date: start_date,
        end_date: end_date,
        current: current,
        responsibilities: responsibilities,
        highlights: highlights,
        source_count: items.size,
        merge_keys: { merge_key: merge_key_for(first) }
      }
    end

    def upsert_experience_skills!(user_work_experience, resume_items)
      # Build counts across source experiences.
      skills = Hash.new { |h, k| h[k] = { count: 0, last_used_on: nil } }

      resume_items.each do |rwe|
        last_used_on = rwe.end_date || rwe.start_date
        last_used_on = Date.current if rwe.current

        rwe.resume_work_experience_skills.each do |row|
          entry = skills[row.skill_tag_id]
          entry[:count] += 1
          entry[:last_used_on] = [ entry[:last_used_on], last_used_on ].compact.max
        end
      end

      skills.each do |skill_tag_id, data|
        UserWorkExperienceSkill.create!(
          user_work_experience: user_work_experience,
          skill_tag_id: skill_tag_id,
          source_count: data[:count],
          last_used_on: data[:last_used_on]
        )
      end
    end
  end
end
