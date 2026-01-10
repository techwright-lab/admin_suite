# frozen_string_literal: true

# UserWorkExperience is a merged, user-level view of work history aggregated across resumes.
# It preserves provenance via UserWorkExperienceSource.
# Can also be manually created/edited by users.
class UserWorkExperience < ApplicationRecord
  belongs_to :user
  belongs_to :company, optional: true
  belongs_to :job_role, optional: true

  has_many :user_work_experience_sources, dependent: :destroy
  has_many :resume_work_experiences, through: :user_work_experience_sources

  has_many :user_work_experience_skills, dependent: :destroy
  has_many :skill_tags, through: :user_work_experience_skills

  # Source type: ai_extracted (from resume analysis) or manual (user-created)
  enum :source_type, [ :ai_extracted, :manual ], default: :ai_extracted

  validates :role_title, presence: true
  validates :company_name, presence: true

  scope :reverse_chronological, -> { order(Arel.sql("COALESCE(end_date, start_date) DESC NULLS LAST"), created_at: :desc) }
  scope :ai_extracted_only, -> { where(source_type: :ai_extracted) }
  scope :manual_only, -> { where(source_type: :manual) }

  # @return [String]
  def display_company_name
    company&.name.presence || company_name.to_s
  end

  # @return [String]
  def display_role_title
    job_role&.title.presence || role_title.to_s
  end
end
