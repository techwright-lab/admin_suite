# frozen_string_literal: true

# ResumeSkill model representing extracted skills from a specific resume
#
# Links a UserResume to a SkillTag with proficiency levels and evidence
#
# @example
#   resume_skill = ResumeSkill.create!(
#     user_resume: resume,
#     skill_tag: skill,
#     model_level: 4,
#     confidence_score: 0.85,
#     category: "Backend",
#     evidence_snippet: "5 years of Ruby on Rails experience"
#   )
#
class ResumeSkill < ApplicationRecord
  # Constants
  PROFICIENCY_LEVELS = (1..5).to_a.freeze
  CATEGORIES = %w[
    Backend
    Frontend
    Fullstack
    Infrastructure
    DevOps
    Data
    Mobile
    Leadership
    Communication
    ProjectManagement
    Design
    Security
    AI/ML
    Other
  ].freeze

  # Associations
  belongs_to :user_resume
  belongs_to :skill_tag

  # Delegations
  delegate :user, to: :user_resume
  delegate :name, to: :skill_tag, prefix: :skill

  # Validations
  validates :model_level, presence: true, inclusion: { in: PROFICIENCY_LEVELS }
  validates :user_level, inclusion: { in: PROFICIENCY_LEVELS }, allow_nil: true
  validates :confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :user_resume_id, uniqueness: { scope: :skill_tag_id, message: "skill already exists for this resume" }

  # Scopes
  scope :by_category, ->(category) { where(category: category) }
  scope :high_confidence, -> { where("confidence_score >= ?", 0.7) }
  scope :user_confirmed, -> { where.not(user_level: nil) }
  scope :alphabetical, -> { joins(:skill_tag).order("skill_tags.name ASC") }
  scope :by_proficiency, -> { order(Arel.sql("COALESCE(user_level, model_level) DESC")) }

  # Callbacks
  after_save :trigger_skill_aggregation
  after_destroy :trigger_skill_aggregation

  # Returns the effective proficiency level (user override or AI-assigned)
  #
  # @return [Integer] Proficiency level 1-5
  def effective_level
    user_level || model_level
  end

  # Checks if user has confirmed/adjusted this skill
  #
  # @return [Boolean]
  def user_confirmed?
    user_level.present?
  end

  # Sets the user-confirmed proficiency level
  #
  # @param level [Integer] Proficiency level 1-5
  # @return [Boolean]
  def confirm_level!(level)
    update!(user_level: level)
  end

  # Returns confidence as a percentage
  #
  # @return [Integer] Confidence percentage 0-100
  def confidence_percentage
    return 0 unless confidence_score

    (confidence_score * 100).round
  end

  # Returns a human-readable proficiency label
  #
  # @return [String] Proficiency description
  def proficiency_label
    case effective_level
    when 1 then "Beginner"
    when 2 then "Elementary"
    when 3 then "Intermediate"
    when 4 then "Advanced"
    when 5 then "Expert"
    else "Unknown"
    end
  end

  private

  # Triggers user skill aggregation after changes
  def trigger_skill_aggregation
    Resumes::SkillAggregationService.new(user).aggregate_skill(skill_tag)
  rescue => e
    Rails.logger.error("Failed to aggregate skill: #{e.message}")
  end
end
