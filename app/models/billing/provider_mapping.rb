# frozen_string_literal: true

module Billing
  # Maps an internal plan to a payment provider's identifiers (e.g. LemonSqueezy product/variant).
  class ProviderMapping < ApplicationRecord
    self.table_name = "billing_provider_mappings"

    PROVIDERS = %w[lemonsqueezy].freeze

    belongs_to :plan, class_name: "Billing::Plan", inverse_of: :provider_mappings

    validates :uuid, presence: true, uniqueness: true
    validates :provider, presence: true
    validates :provider, inclusion: { in: PROVIDERS }
    validates :plan_id, uniqueness: { scope: :provider }

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
