# frozen_string_literal: true

# Provenance join from a merged UserWorkExperience back to individual ResumeWorkExperience rows.
class UserWorkExperienceSource < ApplicationRecord
  belongs_to :user_work_experience
  belongs_to :resume_work_experience

  validates :user_work_experience_id, uniqueness: { scope: :resume_work_experience_id }
end
