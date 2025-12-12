# frozen_string_literal: true

# UserSkill model representing aggregated skill profile across all resumes
#
# Computed from ResumeSkills with weighted averaging based on recency and purpose
#
# @example
#   user_skill = user.user_skills.find_by(skill_tag: ruby_skill)
#   user_skill.aggregated_level # => 4.2
#   user_skill.resume_count # => 3
#
class UserSkill < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :skill_tag

  # Delegations
  delegate :name, to: :skill_tag, prefix: :skill

  # Validations
  validates :aggregated_level, presence: true, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :user_id, uniqueness: { scope: :skill_tag_id, message: "skill already exists for this user" }
  validates :resume_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :by_category, ->(category) { where(category: category) }
  scope :strong_skills, -> { where("aggregated_level >= ?", 4.0) }
  scope :moderate_skills, -> { where(aggregated_level: 2.5..3.9) }
  scope :developing_skills, -> { where("aggregated_level < ?", 2.5) }
  scope :by_level_desc, -> { order(aggregated_level: :desc) }
  scope :by_level_asc, -> { order(aggregated_level: :asc) }
  scope :alphabetical, -> { joins(:skill_tag).order("skill_tags.name ASC") }
  scope :most_demonstrated, -> { order(resume_count: :desc) }
  scope :recent, -> { order(last_demonstrated_at: :desc) }

  # Returns proficiency as a rounded integer
  #
  # @return [Integer] Rounded proficiency level 1-5
  def rounded_level
    aggregated_level.round
  end

  # Returns a human-readable proficiency label
  #
  # @return [String] Proficiency description
  def proficiency_label
    case rounded_level
    when 1 then "Beginner"
    when 2 then "Elementary"
    when 3 then "Intermediate"
    when 4 then "Advanced"
    when 5 then "Expert"
    else "Unknown"
    end
  end

  # Returns confidence as a percentage
  #
  # @return [Integer] Confidence percentage 0-100
  def confidence_percentage
    return 0 unless confidence_score

    (confidence_score * 100).round
  end

  # Checks if this is a strong skill (4+)
  #
  # @return [Boolean]
  def strong?
    aggregated_level >= 4.0
  end

  # Checks if this is a developing skill (<2.5)
  #
  # @return [Boolean]
  def developing?
    aggregated_level < 2.5
  end

  # Returns the source resumes for this skill
  #
  # @return [ActiveRecord::Relation<UserResume>]
  def source_resumes
    UserResume.joins(:resume_skills)
              .where(user: user, resume_skills: { skill_tag: skill_tag })
              .distinct
  end

  # Class method to get skills grouped by category
  #
  # @param user [User] The user
  # @return [Hash] Skills grouped by category
  def self.grouped_by_category(user)
    where(user: user)
      .includes(:skill_tag)
      .order(aggregated_level: :desc)
      .group_by(&:category)
  end

  # Class method to get top N skills for a user
  #
  # @param user [User] The user
  # @param limit [Integer] Number of skills to return
  # @return [ActiveRecord::Relation<UserSkill>]
  def self.top_skills(user, limit: 10)
    where(user: user).by_level_desc.limit(limit)
  end

  # Class method to get skills needing development
  #
  # @param user [User] The user
  # @param limit [Integer] Number of skills to return
  # @return [ActiveRecord::Relation<UserSkill>]
  def self.development_areas(user, limit: 5)
    where(user: user).developing_skills.by_level_asc.limit(limit)
  end
end
