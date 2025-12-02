# frozen_string_literal: true

# SkillTag model representing skills tracked across interviews
class SkillTag < ApplicationRecord
  has_many :application_skill_tags, dependent: :destroy
  has_many :interview_applications, through: :application_skill_tags

  validates :name, presence: true, uniqueness: true

  normalizes :name, with: ->(name) { name.strip.titleize }

  scope :by_category, ->(category) { where(category: category) }
  scope :alphabetical, -> { order(:name) }
  scope :popular, -> { joins(:application_skill_tags).group(:id).order("COUNT(application_skill_tags.id) DESC") }

  # Returns the count of interview applications associated with this skill
  # @return [Integer] Interview application count
  def interview_application_count
    interview_applications.count
  end

  # Finds or creates a skill tag by name
  # @param name [String] Name of the skill
  # @return [SkillTag] The skill tag instance
  def self.find_or_create_by_name(name)
    find_or_create_by(name: name.strip.titleize)
  end
end
