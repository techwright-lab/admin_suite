# frozen_string_literal: true

module Billing
  # A subscription plan displayed in the app and on public pricing pages.
  #
  # Plans are the source-of-truth for pricing/feature entitlements and are managed
  # through the internal developer portal.
  class Plan < ApplicationRecord
    self.table_name = "billing_plans"

    PLAN_TYPES = %w[free recurring one_time].freeze
    INTERVALS = %w[month year].freeze

    has_many :plan_entitlements, class_name: "Billing::PlanEntitlement", dependent: :destroy, inverse_of: :plan
    has_many :features, through: :plan_entitlements
    has_many :provider_mappings, class_name: "Billing::ProviderMapping", dependent: :destroy, inverse_of: :plan

    validates :uuid, presence: true, uniqueness: true
    validates :key, presence: true, uniqueness: { case_sensitive: true }
    validates :name, presence: true
    validates :plan_type, presence: true, inclusion: { in: PLAN_TYPES }
    validates :currency, presence: true
    validates :sort_order, numericality: { only_integer: true }

    validate :validate_interval_for_plan_type
    validate :validate_amount_for_plan_type

    before_validation :ensure_uuid, on: :create
    before_validation :normalize_metadata_json

    after_commit :purge_catalog_cache

    scope :published, -> { where(published: true) }
    scope :ordered, -> { order(sort_order: :asc, amount_cents: :asc, name: :asc) }

    # @return [Boolean] Whether this plan is the free tier.
    def free?
      plan_type == "free"
    end

    # @return [Boolean] Whether this plan is a recurring subscription (e.g. monthly).
    def recurring?
      plan_type == "recurring"
    end

    # @return [Boolean] Whether this plan is a one-time purchase (e.g. Sprint pass).
    def one_time?
      plan_type == "one_time"
    end

    private

    def ensure_uuid
      self.uuid ||= SecureRandom.uuid
    end

    def normalize_metadata_json
      return if metadata.blank?
      return if metadata.is_a?(Hash)

      # The developer portal JSON field can sometimes persist metadata as a JSON string.
      # If that happens, parse it back into an object so views/controllers don't treat
      # it like a Ruby String (e.g. `"..."["pricing_features"]` returning `"pricing_features"`).
      if metadata.is_a?(String)
        parsed = JSON.parse(metadata) rescue nil
        self.metadata = parsed if parsed.is_a?(Hash)
      end
    end

    def validate_interval_for_plan_type
      return if interval.blank?

      unless recurring?
        errors.add(:interval, "must be blank unless plan is recurring")
        return
      end

      errors.add(:interval, "must be month or year") unless INTERVALS.include?(interval)
    end

    def validate_amount_for_plan_type
      return if free?

      errors.add(:amount_cents, "must be present for paid plans") if amount_cents.blank?
      errors.add(:amount_cents, "must be >= 0") if amount_cents.present? && amount_cents.negative?
    end

    def purge_catalog_cache
      Billing::Catalog.purge_cache!
    end
  end
end
