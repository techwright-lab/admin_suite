# frozen_string_literal: true

# Aggregated join between UserWorkExperience and SkillTag.
# Tracks how many source resume experiences mention the skill and when it was last used.
class UserWorkExperienceSkill < ApplicationRecord
  belongs_to :user_work_experience
  belongs_to :skill_tag

  validates :user_work_experience_id, uniqueness: { scope: :skill_tag_id }
  validates :source_count, numericality: { greater_than_or_equal_to: 0 }
end
