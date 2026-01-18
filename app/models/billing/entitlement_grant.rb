# frozen_string_literal: true

module Billing
  # A time-bounded entitlement override for a user (e.g., trials, promos, admin grants).
  #
  # `entitlements` is a JSON map keyed by feature_key:
  #   { "pattern_detection" => { "enabled" => true }, "ai_summaries" => { "enabled" => true, "limit" => 50 } }
  class EntitlementGrant < ApplicationRecord
    self.table_name = "billing_entitlement_grants"

    SOURCES = %w[trial admin promo purchase].freeze

    belongs_to :user
    belongs_to :plan, class_name: "Billing::Plan", foreign_key: :billing_plan_id, optional: true

    validates :uuid, presence: true, uniqueness: true
    validates :source, presence: true, inclusion: { in: SOURCES }
    validates :starts_at, presence: true
    validates :expires_at, presence: true

    validate :validate_time_window

    before_validation :ensure_uuid, on: :create

    scope :active_at, ->(time) { where("starts_at <= ? AND expires_at > ?", time, time) }

    # @param time [Time]
    # @return [Boolean]
    def active?(time: Time.current)
      starts_at <= time && expires_at > time
    end

    private

    def ensure_uuid
      self.uuid ||= SecureRandom.uuid
    end

    def validate_time_window
      return if starts_at.blank? || expires_at.blank?

      errors.add(:expires_at, "must be after starts_at") if expires_at <= starts_at
    end
  end
end
