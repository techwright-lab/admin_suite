# frozen_string_literal: true

# ApplicationSkillTag join model connecting interview applications with skill tags
class ApplicationSkillTag < ApplicationRecord
  self.table_name = "interview_skill_tags"
  
  belongs_to :interview_application, foreign_key: :interview_id
  belongs_to :skill_tag

  validates :interview_application, :skill_tag, presence: true
  validates :interview_id, uniqueness: { scope: :skill_tag_id }
end

