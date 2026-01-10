# frozen_string_literal: true

# Domain model representing professional domains/industries (e.g., FinTech, SaaS, Healthcare)
# Used for user targeting and resume analysis
class Domain < ApplicationRecord
  include Disableable

  has_many :user_target_domains, dependent: :destroy
  has_many :users_targeting, through: :user_target_domains, source: :user

  validates :name, presence: true, uniqueness: true

  normalizes :name, with: ->(name) { name.to_s.strip }
  normalizes :slug, with: ->(slug) { slug.to_s.strip.downcase.gsub(/\s+/, "-").gsub(/[^a-z0-9\-]/, "") }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :alphabetical, -> { order(:name) }
  scope :search, ->(query) { where("name ILIKE ?", "%#{query}%") if query.present? }

  # Returns a display name for the domain
  # @return [String] Domain name
  def display_name
    name
  end

  private

  # Generates a URL-friendly slug from the name
  # @return [void]
  def generate_slug
    self.slug = name.to_s.strip.downcase.gsub(/\s+/, "-").gsub(/[^a-z0-9\-]/, "")
  end
end
