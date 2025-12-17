# frozen_string_literal: true

# JobRole model representing job positions/titles
class JobRole < ApplicationRecord
  include Disableable

  has_many :job_listings, dependent: :destroy
  has_many :interview_applications, dependent: :nullify
  has_many :users_with_current_role, class_name: "User", foreign_key: "current_job_role_id", dependent: :nullify
  has_many :user_target_job_roles, dependent: :destroy
  has_many :users_targeting, through: :user_target_job_roles, source: :user
  belongs_to :category, optional: true

  validates :title, presence: true, uniqueness: true

  normalizes :title, with: ->(title) { title.strip }

  scope :alphabetical, -> { order(:title) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }

  def legacy_category_name
    respond_to?(:legacy_category) ? legacy_category : nil
  end

  # Returns a display name for the job role
  # @return [String] Job role title
  def display_name
    title
  end

  def category_name
    category&.name
  end
end
