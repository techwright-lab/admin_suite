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
  scope :by_department, ->(department_id) { by_category(department_id) }
  scope :with_department, -> { includes(:category).where.not(category_id: nil) }
  scope :search, ->(query) { where("title ILIKE ?", "%#{query}%") if query.present? }

  def legacy_category_name
    respond_to?(:legacy_category) ? legacy_category : nil
  end

  # Returns a display name for the job role
  # @return [String] Job role title
  def display_name
    title
  end

  # Returns category name (alias: department name)
  # @return [String, nil]
  def category_name
    category&.name
  end

  # Alias for department (category with kind: job_role)
  # @return [Category, nil]
  def department
    category
  end

  # Returns department name
  # @return [String, nil]
  def department_name
    category&.name
  end

  # Merges a source job role into a target job role
  #
  # @param source [JobRole] The job role to be merged (will be deleted)
  # @param target [JobRole] The job role to merge into
  # @return [Hash] Result hash with :success, :message/:error keys
  def self.merge_job_roles(source, target)
    if source == target
      return { success: false, error: "Cannot merge a job role into itself." }
    end

    if source.nil? || target.nil?
      return { success: false, error: "Source or target job role not found." }
    end

    stats = {
      job_listings: 0,
      interview_applications: 0,
      users_current: 0,
      user_targets: 0
    }

    transaction do
      # Transfer job_listings
      stats[:job_listings] = JobListing.where(job_role: source).update_all(job_role_id: target.id)

      # Transfer interview_applications
      stats[:interview_applications] = InterviewApplication.where(job_role: source).update_all(job_role_id: target.id)

      # Transfer users with current_job_role
      stats[:users_current] = User.where(current_job_role_id: source.id).update_all(current_job_role_id: target.id)

      # Handle duplicate user_target_job_roles
      duplicate_target_ids = UserTargetJobRole.where(job_role: source)
        .joins("INNER JOIN user_target_job_roles utjr2 ON user_target_job_roles.user_id = utjr2.user_id")
        .where("utjr2.job_role_id = ?", target.id)
        .pluck(:id)
      UserTargetJobRole.where(id: duplicate_target_ids).delete_all

      # Transfer remaining user_target_job_roles
      stats[:user_targets] = UserTargetJobRole.where(job_role: source).update_all(job_role_id: target.id)

      # Delete the source job role
      source.destroy!
    end

    {
      success: true,
      message: "Transferred #{stats[:job_listings]} job listings, #{stats[:interview_applications]} applications, " \
               "#{stats[:users_current]} current users, and #{stats[:user_targets]} target users."
    }
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.error("JobRole merge failed due to duplicate key: #{e.message}")
    { success: false, error: "Merge failed: Some records already exist on the target job role." }
  rescue ActiveRecord::RecordNotDestroyed => e
    Rails.logger.error("JobRole merge failed - could not delete source: #{e.message}")
    { success: false, error: "Merge failed: Could not delete the source job role. #{e.record.errors.full_messages.join(', ')}" }
  rescue => e
    Rails.logger.error("JobRole merge failed: #{e.class} - #{e.message}")
    { success: false, error: "Merge failed: #{e.message}" }
  end
end
