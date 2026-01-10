# frozen_string_literal: true

# ResumeWorkExperience represents one work experience extracted from a specific resume.
# It stores rich work history (dates, responsibilities, highlights) and can be linked
# to canonical Company/JobRole records when possible.
class ResumeWorkExperience < ApplicationRecord
  belongs_to :user_resume
  belongs_to :company, optional: true
  belongs_to :job_role, optional: true

  has_many :resume_work_experience_skills, dependent: :destroy
  has_many :skill_tags, through: :resume_work_experience_skills

  scope :chronological, -> { order(Arel.sql("COALESCE(start_date, end_date) ASC NULLS LAST"), created_at: :asc) }
  scope :reverse_chronological, -> { order(Arel.sql("COALESCE(end_date, start_date) DESC NULLS LAST"), created_at: :desc) }

  # @return [String]
  def display_company_name
    company&.name.presence || company_name.to_s
  end

  # @return [String]
  def display_role_title
    job_role&.title.presence || role_title.to_s
  end
end
