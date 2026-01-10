# frozen_string_literal: true

# UserResume model representing uploaded CVs/resumes for skill extraction
#
# @example
#   resume = user.user_resumes.create!(name: "Backend - Generic", file: uploaded_file)
#   AnalyzeResumeJob.perform_later(resume)
#
class UserResume < ApplicationRecord
  extend FriendlyId
  friendly_id :slug_candidates, use: [ :slugged, :finders ]

  # Constants
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    text/plain
  ].freeze

  MAX_FILE_SIZE = 10.megabytes

  # Enums
  enum :purpose, {
    generic: 0,
    company_specific: 1,
    role_specific: 2
  }, prefix: true

  enum :analysis_status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }, prefix: true

  # Associations
  belongs_to :user
  has_many :resume_skills, dependent: :destroy
  has_many :skill_tags, through: :resume_skills
  has_many :resume_work_experiences, dependent: :destroy

  # Target roles and companies (many-to-many)
  has_many :user_resume_target_job_roles, dependent: :destroy
  has_many :target_job_roles, through: :user_resume_target_job_roles, source: :job_role
  has_many :user_resume_target_companies, dependent: :destroy
  has_many :target_companies, through: :user_resume_target_companies, source: :company

  # ActiveStorage
  has_one_attached :file

  # Validations
  validates :name, presence: true
  validates :file, presence: true, on: :create

  validate :acceptable_file, if: -> { file.attached? }

  # Scopes
  scope :by_user, ->(user) { where(user: user) }
  scope :analyzed, -> { where(analysis_status: :completed) }
  scope :pending_analysis, -> { where(analysis_status: :pending) }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :by_purpose, ->(purpose) { where(purpose: purpose) }

  # Callbacks
  after_create_commit :enqueue_analysis

  def slug_candidates
    [
      :name,
      [ :name, :purpose ],
      [ :name, :purpose, :user_uuid ]
    ]
  end

  def user_uuid
    user.uuid
  end

  # Returns the file extension
  #
  # @return [String, nil] File extension (e.g., "pdf", "docx")
  def file_extension
    return nil unless file.attached?

    file.filename.extension.downcase
  end

  # Returns a human-readable file type
  #
  # @return [String] File type description
  def file_type
    case file_extension
    when "pdf" then "PDF"
    when "doc" then "Word (DOC)"
    when "docx" then "Word (DOCX)"
    when "txt" then "Plain Text"
    else "Unknown"
    end
  end

  # Checks if analysis is complete
  #
  # @return [Boolean]
  def analyzed?
    analysis_status_completed?
  end

  # Checks if analysis is in progress
  #
  # @return [Boolean]
  def analyzing?
    analysis_status_processing?
  end

  # Checks if this resume has any target roles
  #
  # @return [Boolean]
  def has_target_roles?
    target_job_roles.exists?
  end

  # Checks if this resume has any target companies
  #
  # @return [Boolean]
  def has_target_companies?
    target_companies.exists?
  end

  # Returns a summary of targets for display
  #
  # @return [String, nil]
  def targets_summary
    parts = []
    parts << target_job_roles.pluck(:title).join(", ") if has_target_roles?
    parts << "@ #{target_companies.pluck(:name).join(", ")}" if has_target_companies?
    parts.any? ? parts.join(" ") : nil
  end

  # Returns the effective proficiency level for a skill
  # Prefers user_level over model_level
  #
  # @param skill_tag [SkillTag] The skill to check
  # @return [Integer, nil] Proficiency level 1-5
  def proficiency_for(skill_tag)
    resume_skill = resume_skills.find_by(skill_tag: skill_tag)
    return nil unless resume_skill

    resume_skill.user_level || resume_skill.model_level
  end

  # Marks analysis as started
  #
  # @return [Boolean]
  def start_analysis!
    update!(analysis_status: :processing)
  end

  # Marks analysis as completed
  #
  # @param summary [String, nil] AI-generated summary
  # @return [Boolean]
  def complete_analysis!(summary: nil)
    update!(
      analysis_status: :completed,
      analyzed_at: Time.current,
      analysis_summary: summary
    )
  end

  # Marks analysis as failed
  #
  # @param error_message [String, nil] Error description
  # @return [Boolean]
  def fail_analysis!(error_message: nil)
    update!(
      analysis_status: :failed,
      extracted_data: extracted_data.merge(error: error_message)
    )
  end

  private

  # Validates attached file type and size
  def acceptable_file
    unless file.blob.byte_size <= MAX_FILE_SIZE
      errors.add(:file, "is too large (max #{MAX_FILE_SIZE / 1.megabyte}MB)")
    end

    unless ALLOWED_CONTENT_TYPES.include?(file.blob.content_type)
      errors.add(:file, "must be a PDF, Word document, or plain text file")
    end
  end

  # Enqueues background analysis job
  def enqueue_analysis
    AnalyzeResumeJob.perform_later(self)
  end
end
