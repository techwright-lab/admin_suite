# frozen_string_literal: true

module Billing
  # Joins a Plan to a Feature and defines whether it's enabled and/or quota-limited.
  class PlanEntitlement < ApplicationRecord
    self.table_name = "billing_plan_entitlements"

    belongs_to :plan, class_name: "Billing::Plan", inverse_of: :plan_entitlements
    belongs_to :feature, class_name: "Billing::Feature", inverse_of: :plan_entitlements

    validates :plan_id, uniqueness: { scope: :feature_id }

    validate :validate_limit_for_feature_kind

    after_commit :purge_catalog_cache

    private

    def validate_limit_for_feature_kind
      return if feature.nil?

      # For quota features, a blank limit means "unlimited".
      # (We still allow setting an explicit numeric cap for Free/trials.)
      if feature.kind == "quota" && limit.present?
        errors.add(:limit, "must be >= 0") if limit.to_i.negative?
      end

      if feature.kind == "boolean" && limit.present?
        errors.add(:limit, "must be blank for boolean features")
      end
    end

    def purge_catalog_cache
      Billing::Catalog.purge_cache!
    end
  end
end
