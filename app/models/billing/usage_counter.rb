# frozen_string_literal: true

module Billing
  # Tracks usage for a given feature key and time window (for quota enforcement).
  class UsageCounter < ApplicationRecord
    self.table_name = "billing_usage_counters"

    belongs_to :user

    validates :uuid, presence: true, uniqueness: true
    validates :feature_key, presence: true
    validates :used, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :period_starts_at, presence: true
    validates :period_ends_at, presence: true
    validates :feature_key, uniqueness: { scope: [ :user_id, :period_starts_at ] }

    validate :validate_period

    before_validation :ensure_uuid, on: :create

    # Increments usage by a delta for the given period, creating the counter if needed.
    #
    # @param user [User]
    # @param feature_key [String]
    # @param period_starts_at [Time]
    # @param period_ends_at [Time]
    # @param delta [Integer]
    # @return [Billing::UsageCounter]
    def self.increment!(user:, feature_key:, period_starts_at:, period_ends_at:, delta: 1)
      counter = find_or_create_by!(user: user, feature_key: feature_key, period_starts_at: period_starts_at) do |c|
        c.period_ends_at = period_ends_at
      end

      counter.with_lock do
        counter.used += delta
        counter.save!
      end

      counter
    end

    private

    def ensure_uuid
      self.uuid ||= SecureRandom.uuid
    end

    def validate_period
      return if period_starts_at.blank? || period_ends_at.blank?

      errors.add(:period_ends_at, "must be after period_starts_at") if period_ends_at <= period_starts_at
    end
  end
end
