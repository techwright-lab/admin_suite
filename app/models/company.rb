# frozen_string_literal: true

# Company model representing companies users apply to
class Company < ApplicationRecord
  include Disableable

  has_many :job_listings, dependent: :destroy
  has_many :interview_applications, dependent: :nullify
  has_many :users_with_current_company, class_name: "User", foreign_key: "current_company_id", dependent: :nullify
  has_many :user_target_companies, dependent: :destroy
  has_many :users_targeting, through: :user_target_companies, source: :user
  has_many :email_senders, dependent: :nullify
  has_many :auto_detected_email_senders, class_name: "EmailSender", foreign_key: "auto_detected_company_id", dependent: :nullify

  validates :name, presence: true, uniqueness: true

  normalizes :name, with: ->(name) { name.strip }
  normalizes :website, with: ->(website) { website&.strip }

  scope :alphabetical, -> { order(:name) }
  scope :with_logo, -> { where.not(logo_url: nil) }

  # Returns a display name for the company
  # @return [String] Company name
  def display_name
    name
  end

  # Checks if company has a logo
  # @return [Boolean] True if logo exists
  def has_logo?
    logo_url.present?
  end

  # Merges a source company into a target company
  #
  # @param source [Company] The company to be merged (will be deleted)
  # @param target [Company] The company to merge into
  # @return [Hash] Result hash with :success, :message/:error keys
  def self.merge_companies(source, target)
    if source == target
      return { success: false, error: "Cannot merge a company into itself." }
    end

    if source.nil? || target.nil?
      return { success: false, error: "Source or target company not found." }
    end

    stats = {
      job_listings: 0,
      interview_applications: 0,
      users_current: 0,
      user_targets: 0,
      email_senders: 0
    }

    transaction do
      # Transfer job_listings
      stats[:job_listings] = JobListing.where(company: source).update_all(company_id: target.id)

      # Transfer interview_applications
      stats[:interview_applications] = InterviewApplication.where(company: source).update_all(company_id: target.id)

      # Transfer users with current_company
      stats[:users_current] = User.where(current_company_id: source.id).update_all(current_company_id: target.id)

      # Handle duplicate user_target_companies
      duplicate_target_ids = UserTargetCompany.where(company: source)
        .joins("INNER JOIN user_target_companies utc2 ON user_target_companies.user_id = utc2.user_id")
        .where("utc2.company_id = ?", target.id)
        .pluck(:id)
      UserTargetCompany.where(id: duplicate_target_ids).delete_all

      # Transfer remaining user_target_companies
      stats[:user_targets] = UserTargetCompany.where(company: source).update_all(company_id: target.id)

      # Transfer email_senders
      stats[:email_senders] = EmailSender.where(company: source).update_all(company_id: target.id)
      EmailSender.where(auto_detected_company_id: source.id).update_all(auto_detected_company_id: target.id)

      # Delete the source company
      source.destroy!
    end

    {
      success: true,
      message: "Transferred #{stats[:job_listings]} job listings, #{stats[:interview_applications]} applications, " \
               "#{stats[:users_current]} current users, #{stats[:user_targets]} target users, " \
               "and #{stats[:email_senders]} email senders."
    }
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.error("Company merge failed due to duplicate key: #{e.message}")
    { success: false, error: "Merge failed: Some records already exist on the target company." }
  rescue ActiveRecord::RecordNotDestroyed => e
    Rails.logger.error("Company merge failed - could not delete source: #{e.message}")
    { success: false, error: "Merge failed: Could not delete the source company. #{e.record.errors.full_messages.join(', ')}" }
  rescue => e
    Rails.logger.error("Company merge failed: #{e.class} - #{e.message}")
    { success: false, error: "Merge failed: #{e.message}" }
  end
end
