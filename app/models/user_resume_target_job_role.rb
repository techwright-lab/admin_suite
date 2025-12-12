# frozen_string_literal: true

# Join model connecting UserResume to target JobRoles
class UserResumeTargetJobRole < ApplicationRecord
  belongs_to :user_resume
  belongs_to :job_role

  validates :user_resume_id, uniqueness: { scope: :job_role_id }
end
