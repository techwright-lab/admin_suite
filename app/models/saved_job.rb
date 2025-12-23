# frozen_string_literal: true

# SavedJob model representing a user-saved job lead.
#
# A saved job can be created from:
# - an existing Opportunity (email-sourced lead), or
# - a pasted URL (new job lead).
#
# Exactly one of `opportunity_id` or `url` must be present.
#
# @example Save from an opportunity
#   SavedJob.create!(user: user, opportunity: opportunity)
#
# @example Save from a URL
#   SavedJob.create!(user: user, url: "https://boards.greenhouse.io/acme/jobs/123")
#
class SavedJob < ApplicationRecord
  include Transitionable

  belongs_to :user
  belongs_to :opportunity, optional: true

  has_one :fit_assessment, as: :fittable, dependent: :destroy

  validates :user, presence: true
  validate :exactly_one_source
  validate :valid_url_format, if: -> { url.present? }

  aasm column: :status, with_klass: BaseAasm do
    requires_guards!
    log_transitions!

    state :active, initial: true
    state :archived

    event :archive_removed do
      transitions from: :active, to: :archived, after: :set_archived_as_removed
    end

    event :restore do
      transitions from: :archived, to: :active, after: :clear_archived_metadata
    end
  end

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: "active") }
  scope :archived, -> { where(status: "archived") }
  scope :converted, -> { where.not(converted_at: nil) }
  scope :unconverted, -> { where(converted_at: nil) }

  # Returns the best URL for conversion or display.
  #
  # @return [String, nil]
  def effective_url
    url.presence || opportunity&.primary_job_link
  end

  private

  # @return [void]
  def set_archived_as_removed
    update_columns(
      archived_reason: "removed_saved_job",
      archived_at: Time.current
    )
  end

  # @return [void]
  def clear_archived_metadata
    update_columns(
      archived_reason: nil,
      archived_at: nil
    )
  end

  def exactly_one_source
    if opportunity_id.present? && url.present?
      errors.add(:base, "Saved job must have either an opportunity or a URL, not both")
    elsif opportunity_id.blank? && url.blank?
      errors.add(:base, "Saved job must have an opportunity or a URL")
    end
  end

  def valid_url_format
    uri = URI.parse(url)
    return if uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    errors.add(:url, "must be a valid HTTP/HTTPS URL")
  rescue URI::InvalidURIError
    errors.add(:url, "must be a valid HTTP/HTTPS URL")
  end
end
