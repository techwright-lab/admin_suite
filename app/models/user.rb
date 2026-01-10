# frozen_string_literal: true

# User model representing registered users
class User < ApplicationRecord
  extend FriendlyId
  friendly_id :slug_candidates, use: [ :slugged, :finders ]

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :interview_applications, dependent: :destroy
  has_many :interview_rounds, through: :interview_applications
  has_one :preference, class_name: "UserPreference", dependent: :destroy
  has_many :connected_accounts, dependent: :destroy
  has_many :synced_emails, dependent: :destroy
  has_many :opportunities, dependent: :destroy
  has_many :saved_jobs, dependent: :destroy
  has_many :fit_assessments, dependent: :destroy
  has_many :interview_prep_artifacts, dependent: :destroy

  # =================================================================
  # Billing & subscriptions
  # =================================================================
  has_many :billing_customers, class_name: "Billing::Customer", dependent: :destroy
  has_many :billing_subscriptions, class_name: "Billing::Subscription", dependent: :destroy
  has_many :billing_entitlement_grants, class_name: "Billing::EntitlementGrant", dependent: :destroy
  has_many :billing_usage_counters, class_name: "Billing::UsageCounter", dependent: :destroy

  # Resume and skill profile associations
  has_many :user_resumes, dependent: :destroy
  has_many :user_skills, dependent: :destroy
  has_many :skill_tags, through: :user_skills

  # Current job role and company associations
  belongs_to :current_job_role, class_name: "JobRole", optional: true
  belongs_to :current_company, class_name: "Company", optional: true

  # Target job roles, companies, and domains
  has_many :user_target_job_roles, dependent: :destroy
  has_many :target_job_roles, through: :user_target_job_roles, source: :job_role
  has_many :user_target_companies, dependent: :destroy
  has_many :target_companies, through: :user_target_companies, source: :company
  has_many :user_target_domains, dependent: :destroy
  has_many :target_domains, through: :user_target_domains, source: :domain

  # Work experience (aggregated from resumes + manual entries)
  has_many :user_work_experiences, dependent: :destroy

  # Virtual attribute for terms acceptance checkbox
  attribute :terms_accepted, :boolean, default: false

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :terms_accepted, acceptance: { accept: true, message: "You must accept the Terms of Service and Privacy Policy" }, on: :create

  # Set terms_accepted_at when terms are accepted
  before_create :set_terms_accepted_at, if: :terms_accepted

  # Generate token for email verification
  generates_token_for :email_verification, expires_in: 24.hours

  after_create :create_default_preference

  before_create :generate_uuid

  # Returns the user's preference or builds a default one
  # @return [UserPreference]
  def preference
    super || build_preference
  end

  # Returns the slug candidates for the user
  # @return [Array<String>]
  def slug_candidates
    [
      :name,
      [ :name, :uuid ]
    ]
  end

  # Returns the total number of applications for this user
  # @return [Integer] Total application count
  def total_applications_count
    interview_applications.count
  end

  # Returns applications grouped by status
  # @return [Hash] Applications grouped by status
  def applications_by_status
    interview_applications.group_by(&:status)
  end

  # Returns the user's display name or email
  # @return [String]
  def display_name
    name.presence || email_address.split("@").first
  end

  # Returns current role display name
  # @return [String, nil]
  def current_role_name
    current_job_role&.title
  end

  # Returns current company display name
  # @return [String, nil]
  def current_company_name
    current_company&.name
  end

  # Checks if the user is an admin
  # @return [Boolean] True if user has admin privileges
  def admin?
    is_admin == true
  end

  # Returns the Google connected account if any
  # @return [ConnectedAccount, nil]
  def google_account
    connected_accounts.google.first
  end

  # Checks if user has Google connected
  # @return [Boolean]
  def google_connected?
    connected_accounts.google.exists?
  end

  # Checks if the user's email has been verified
  # @return [Boolean]
  def email_verified?
    email_verified_at.present?
  end

  # Marks the user's email as verified
  # @return [Boolean]
  def verify_email!
    update(email_verified_at: Time.current)
  end

  # Checks if user signed up via OAuth
  # @return [Boolean]
  def oauth_user?
    oauth_provider.present?
  end

  # Internal billing override for staff/admins (all features enabled).
  #
  # @return [Boolean]
  def billing_admin_access?
    Billing::AdminAccessService.new(user: self).active?
  end

  # Returns the user's aggregated skill profile
  # @return [ActiveRecord::Relation<UserSkill>]
  def skill_profile
    user_skills.includes(:skill_tag).by_level_desc
  end

  # Returns the user's top skills
  # @param limit [Integer] Number of skills to return
  # @return [ActiveRecord::Relation<UserSkill>]
  def top_skills(limit: 10)
    UserSkill.top_skills(self, limit: limit)
  end

  # Checks if user has uploaded any resumes
  # @return [Boolean]
  def has_resumes?
    user_resumes.exists?
  end

  # Returns the count of analyzed resumes
  # @return [Integer]
  def analyzed_resumes_count
    user_resumes.analyzed.count
  end

  private

  def create_default_preference
    create_preference! unless preference.persisted?
  end

  def set_terms_accepted_at
    self.terms_accepted_at = Time.current
  end

  # Generates a UUID for the user
  # @return [String]
  def generate_uuid
    self.uuid = SecureRandom.uuid
  end
end
