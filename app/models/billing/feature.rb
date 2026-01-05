# frozen_string_literal: true

module Billing
  # A feature flag or quota that can be granted by plans and/or explicit grants.
  class Feature < ApplicationRecord
    self.table_name = "billing_features"

    KINDS = %w[boolean quota].freeze

    has_many :plan_entitlements, class_name: "Billing::PlanEntitlement", dependent: :destroy, inverse_of: :feature
    has_many :plans, through: :plan_entitlements

    validates :uuid, presence: true, uniqueness: true
    validates :key, presence: true, uniqueness: { case_sensitive: true }
    validates :name, presence: true
    validates :kind, presence: true, inclusion: { in: KINDS }

    before_validation :ensure_uuid, on: :create

    after_commit :purge_catalog_cache

    private

    def ensure_uuid
      self.uuid ||= SecureRandom.uuid
    end

    def purge_catalog_cache
      Billing::Catalog.purge_cache!
    end
  end
end
