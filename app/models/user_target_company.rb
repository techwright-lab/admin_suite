# frozen_string_literal: true

# UserTargetCompany join model for user's target companies
class UserTargetCompany < ApplicationRecord
  belongs_to :user
  belongs_to :company

  validates :user, presence: true
  validates :company, presence: true
  validates :company_id, uniqueness: { scope: :user_id }

  scope :ordered, -> { order(priority: :asc, created_at: :asc) }
end
