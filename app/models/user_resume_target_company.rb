# frozen_string_literal: true

# Join model connecting UserResume to target Companies
class UserResumeTargetCompany < ApplicationRecord
  belongs_to :user_resume
  belongs_to :company

  validates :user_resume_id, uniqueness: { scope: :company_id }
end
