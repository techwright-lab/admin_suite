# frozen_string_literal: true

# SkillTag model representing skills tracked across interviews and resumes
class SkillTag < ApplicationRecord
  include Disableable

  # Skill name aliases for normalization (maps variations to canonical names)
  SKILL_ALIASES = {
    "postgres" => "Postgresql",
    "postgre" => "Postgresql",
    "psql" => "Postgresql",
    "js" => "Javascript",
    "ts" => "Typescript",
    "react.js" => "React",
    "reactjs" => "React",
    "node.js" => "Node",
    "nodejs" => "Node",
    "vue.js" => "Vue",
    "vuejs" => "Vue",
    "k8s" => "Kubernetes",
    "aws" => "Aws",
    "gcp" => "Google Cloud",
    "ror" => "Ruby On Rails"
  }.freeze

  # Interview associations
  has_many :application_skill_tags, dependent: :destroy
  has_many :interview_applications, through: :application_skill_tags
  belongs_to :category, optional: true

  # Resume associations
  has_many :resume_skills, dependent: :destroy
  has_many :user_resumes, through: :resume_skills
  has_many :user_skills, dependent: :destroy
  has_many :users, through: :user_skills

  validates :name, presence: true, uniqueness: true

  normalizes :name, with: ->(name) { normalize_skill_name(name) }

  scope :by_category, ->(category_id) { where(category_id: category_id) }
  scope :alphabetical, -> { order(:name) }
  scope :popular, -> { joins("INNER JOIN interview_skill_tags ON interview_skill_tags.skill_tag_id = skill_tags.id").group("skill_tags.id").order("COUNT(interview_skill_tags.id) DESC") }
  scope :from_resumes, -> { joins(:resume_skills).distinct }

  def category_name
    category&.name
  end

  def legacy_category_name
    respond_to?(:legacy_category) ? legacy_category : nil
  end

  # Returns the count of interview applications associated with this skill
  # @return [Integer] Interview application count
  def interview_application_count
    interview_applications.count
  end

  # Finds or creates a skill tag by name (with alias normalization)
  # @param name [String] Name of the skill
  # @return [SkillTag] The skill tag instance
  def self.find_or_create_by_name(name)
    normalized = normalize_skill_name(name)
    find_or_create_by(name: normalized)
  end

  # Normalizes a skill name, handling aliases
  # @param name [String] Raw skill name
  # @return [String] Normalized skill name
  def self.normalize_skill_name(name)
    cleaned = name.to_s.strip.downcase
    canonical = SKILL_ALIASES[cleaned] || cleaned.titleize
    canonical
  end

  # Merges duplicate skills into one
  # @param source_skill [SkillTag] The skill to merge from
  # @param target_skill [SkillTag] The skill to merge into
  # Merges a source skill tag into a target skill tag
  #
  # @param source_skill [SkillTag] The skill to be merged (will be deleted)
  # @param target_skill [SkillTag] The skill to merge into
  # @return [Hash] Result hash with :success, :message/:error keys
  def self.merge_skills(source_skill, target_skill)
    if source_skill == target_skill
      return { success: false, error: "Cannot merge a skill tag into itself." }
    end

    if source_skill.nil? || target_skill.nil?
      return { success: false, error: "Source or target skill tag not found." }
    end

    stats = { resume_skills: 0, user_skills: 0, application_skills: 0 }

    transaction do
      # Handle duplicate resume_skills by removing them first
      # Note: resume_skills uses user_resume_id (not resume_id)
      duplicate_resume_ids = ResumeSkill.where(skill_tag: source_skill)
        .joins("INNER JOIN resume_skills rs2 ON resume_skills.user_resume_id = rs2.user_resume_id")
        .where("rs2.skill_tag_id = ?", target_skill.id)
        .pluck(:id)
      ResumeSkill.where(id: duplicate_resume_ids).delete_all

      # Update remaining resume_skills
      stats[:resume_skills] = ResumeSkill.where(skill_tag: source_skill).update_all(skill_tag_id: target_skill.id)

      # Handle duplicate user_skills by removing them first
      duplicate_user_ids = UserSkill.where(skill_tag: source_skill)
        .joins("INNER JOIN user_skills us2 ON user_skills.user_id = us2.user_id")
        .where("us2.skill_tag_id = ?", target_skill.id)
        .pluck(:id)
      UserSkill.where(id: duplicate_user_ids).delete_all

      # Update remaining user_skills
      stats[:user_skills] = UserSkill.where(skill_tag: source_skill).update_all(skill_tag_id: target_skill.id)

      # Handle duplicate interview_skill_tags by removing them first
      # Note: ApplicationSkillTag maps to interview_skill_tags table with interview_id column
      duplicate_app_ids = ApplicationSkillTag.where(skill_tag: source_skill)
        .joins("INNER JOIN interview_skill_tags ist2 ON interview_skill_tags.interview_id = ist2.interview_id")
        .where("ist2.skill_tag_id = ?", target_skill.id)
        .pluck(:id)
      ApplicationSkillTag.where(id: duplicate_app_ids).delete_all

      # Update remaining interview_skill_tags
      stats[:application_skills] = ApplicationSkillTag.where(skill_tag: source_skill).update_all(skill_tag_id: target_skill.id)

      # Delete the source skill
      source_skill.destroy!
    end

    {
      success: true,
      message: "Transferred #{stats[:resume_skills]} resume skills, #{stats[:user_skills]} user skills, and #{stats[:application_skills]} application skills."
    }
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.error("Merge failed due to duplicate key: #{e.message}")
    { success: false, error: "Merge failed: Some records already exist on the target skill. Please try again." }
  rescue ActiveRecord::RecordNotDestroyed => e
    Rails.logger.error("Merge failed - could not delete source: #{e.message}")
    { success: false, error: "Merge failed: Could not delete the source skill tag. #{e.record.errors.full_messages.join(', ')}" }
  rescue => e
    Rails.logger.error("Merge failed: #{e.class} - #{e.message}")
    { success: false, error: "Merge failed: #{e.message}" }
  end
end
