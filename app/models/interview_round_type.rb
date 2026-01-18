# frozen_string_literal: true

# InterviewRoundType model representing granular interview round classifications.
#
# Round types are associated with departments (Categories) to enable per-department
# customization. A nil category means the round type is universal (available to all).
#
# Examples: "Coding Interview", "System Design", "Behavioral", "Case Study"
class InterviewRoundType < ApplicationRecord
  include Disableable

  # Associations
  belongs_to :category, optional: true
  has_many :interview_rounds, dependent: :nullify

  # Validations
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  # Normalizations
  normalizes :slug, with: ->(s) { s.to_s.parameterize.underscore }
  normalizes :name, with: ->(n) { n.to_s.strip }

  # Scopes
  scope :alphabetical, -> { order(:name) }
  scope :ordered, -> { order(:position, :name) }
  scope :universal, -> { where(category_id: nil) }
  scope :for_department, ->(cat_id) { where(category_id: [ nil, cat_id ]) }
  scope :search, ->(query) { where("name ILIKE ?", "%#{query}%") if query.present? }

  # Returns the display name for this round type
  #
  # @return [String] The round type name
  def display_name
    name
  end

  # Returns the department name if associated with one
  #
  # @return [String, nil] The department name or nil if universal
  def department_name
    category&.name
  end

  # Alias for department (category with kind: job_role)
  #
  # @return [Category, nil]
  def department
    category
  end

  # Checks if this round type is universal (available to all departments)
  #
  # @return [Boolean] True if universal
  def universal?
    category_id.nil?
  end

  # Finds a round type by slug
  #
  # @param slug [String] The slug to search for
  # @return [InterviewRoundType, nil] The round type or nil
  def self.find_by_slug(slug)
    find_by(slug: slug.to_s.parameterize.underscore)
  end
end
