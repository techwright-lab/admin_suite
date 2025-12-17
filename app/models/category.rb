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
end
