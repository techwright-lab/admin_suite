# frozen_string_literal: true

# Category model used to group JobRoles and SkillTags with dedup-friendly semantics.
class Category < ApplicationRecord
  include Disableable

  enum :kind, { job_role: 0, skill_tag: 1 }

  has_many :job_roles, dependent: :nullify
  has_many :skill_tags, dependent: :nullify

  validates :name, presence: true
  validates :kind, presence: true

  normalizes :name, with: ->(name) { name.to_s.strip }

  scope :alphabetical, -> { order(:name) }
  scope :for_kind, ->(kind) { where(kind: kind) }

  # Merges a source category into a target category
  #
  # @param source [Category] The category to be merged (will be deleted)
  # @param target [Category] The category to merge into
  # @return [Hash] Result hash with :success, :message/:error keys
  def self.merge_categories(source, target)
    if source == target
      return { success: false, error: "Cannot merge a category into itself." }
    end

    if source.nil? || target.nil?
      return { success: false, error: "Source or target category not found." }
    end

    if source.kind != target.kind
      return { success: false, error: "Cannot merge categories of different kinds (#{source.kind} vs #{target.kind})." }
    end

    stats = { job_roles: 0, skill_tags: 0 }

    transaction do
      # Transfer job_roles
      stats[:job_roles] = JobRole.where(category: source).update_all(category_id: target.id)

      # Transfer skill_tags
      stats[:skill_tags] = SkillTag.where(category: source).update_all(category_id: target.id)

      # Delete the source category
      source.destroy!
    end

    {
      success: true,
      message: "Transferred #{stats[:job_roles]} job roles and #{stats[:skill_tags]} skill tags."
    }
  rescue ActiveRecord::RecordNotDestroyed => e
    Rails.logger.error("Category merge failed - could not delete source: #{e.message}")
    { success: false, error: "Merge failed: Could not delete the source category. #{e.record.errors.full_messages.join(', ')}" }
  rescue => e
    Rails.logger.error("Category merge failed: #{e.class} - #{e.message}")
    { success: false, error: "Merge failed: #{e.message}" }
  end
end
