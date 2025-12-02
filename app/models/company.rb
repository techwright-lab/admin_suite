# frozen_string_literal: true

# Company model representing companies users apply to
class Company < ApplicationRecord
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
end
