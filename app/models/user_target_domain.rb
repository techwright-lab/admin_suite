# frozen_string_literal: true

# UserTargetDomain join model for user's target domains
class UserTargetDomain < ApplicationRecord
  belongs_to :user
  belongs_to :domain

  validates :user, presence: true
  validates :domain, presence: true
  validates :domain_id, uniqueness: { scope: :user_id }

  scope :ordered, -> { order(priority: :asc, created_at: :asc) }
end
