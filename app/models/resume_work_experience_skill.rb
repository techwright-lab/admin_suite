# frozen_string_literal: true

# Join model linking a ResumeWorkExperience to a SkillTag (skills used in that role).
class ResumeWorkExperienceSkill < ApplicationRecord
  belongs_to :resume_work_experience
  belongs_to :skill_tag

  validates :resume_work_experience_id, uniqueness: { scope: :skill_tag_id }
  validates :confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
end
