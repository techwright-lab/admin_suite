# frozen_string_literal: true

# FitAssessment model representing a user's fit score for a specific item.
#
# The fittable is polymorphic and is expected to be owned by the same user:
# - Opportunity
# - SavedJob
# - InterviewApplication
#
# @example
#   FitAssessment.create!(user: user, fittable: opportunity, score: 82, status: :computed)
#
class FitAssessment < ApplicationRecord
  belongs_to :user
  belongs_to :fittable, polymorphic: true

  enum :status, { pending: 0, computed: 1, failed: 2 }, default: :pending

  validates :user, presence: true
  validates :fittable, presence: true
  validates :score,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
    allow_nil: true

  validate :score_required_when_computed
  validate :fittable_owned_by_user

  private

  def score_required_when_computed
    return unless computed?
    return if score.present?

    errors.add(:score, "must be present when computed")
  end

  def fittable_owned_by_user
    return unless fittable && user
    return unless fittable.respond_to?(:user_id)

    return if fittable.user_id == user_id

    errors.add(:user, "must match the fittable's owner")
  end
end

