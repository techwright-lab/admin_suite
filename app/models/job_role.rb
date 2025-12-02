# frozen_string_literal: true

# JobRole model representing job positions/titles
class JobRole < ApplicationRecord
  has_many :job_listings, dependent: :destroy
  has_many :interview_applications, dependent: :nullify
  has_many :users_with_current_role, class_name: "User", foreign_key: "current_job_role_id", dependent: :nullify
  has_many :user_target_job_roles, dependent: :destroy
  has_many :users_targeting, through: :user_target_job_roles, source: :user

  validates :title, presence: true, uniqueness: true

  normalizes :title, with: ->(title) { title.strip }

  scope :alphabetical, -> { order(:title) }
  scope :by_category, ->(category) { where(category: category) }

  # Returns a display name for the job role
  # @return [String] Job role title
  def display_name
    title
  end

  # Returns all unique categories
  # @return [Array<String>] List of categories
  def self.categories
    distinct.pluck(:category).compact.sort
  end
end
