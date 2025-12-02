# frozen_string_literal: true

# UserTargetJobRole join model for user's target job roles
class UserTargetJobRole < ApplicationRecord
  belongs_to :user
  belongs_to :job_role

  validates :user, presence: true
  validates :job_role, presence: true
  validates :job_role_id, uniqueness: { scope: :user_id }

  scope :ordered, -> { order(priority: :asc, created_at: :asc) }
end
