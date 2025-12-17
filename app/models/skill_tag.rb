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
  scope :popular, -> { joins(:application_skill_tags).group(:id).order("COUNT(application_skill_tags.id) DESC") }
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
  # @return [Boolean] True if merge succeeded
  def self.merge_skills(source_skill, target_skill)
    return false if source_skill == target_skill

    transaction do
      # Update all resume_skills
      ResumeSkill.where(skill_tag: source_skill).update_all(skill_tag_id: target_skill.id)

      # Update all user_skills
      UserSkill.where(skill_tag: source_skill).update_all(skill_tag_id: target_skill.id)

      # Update all application_skill_tags
      ApplicationSkillTag.where(skill_tag: source_skill).update_all(skill_tag_id: target_skill.id)

      # Delete the source skill
      source_skill.destroy!
    end

    true
  rescue ActiveRecord::RecordNotUnique
    # Handle duplicate key errors by removing conflicting records first
    false
  end
end
