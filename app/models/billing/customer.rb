# frozen_string_literal: true

module Billing
  # Stores the mapping between an internal user and a payment provider's customer record.
  class Customer < ApplicationRecord
    self.table_name = "billing_customers"

    PROVIDERS = %w[lemonsqueezy].freeze

    belongs_to :user
    has_many :orders, class_name: "Billing::Order", foreign_key: :billing_customer_id, dependent: :nullify

    store_accessor :urls, :customer_portal_url, :latest_receipt_url

    validates :uuid, presence: true, uniqueness: true
    validates :provider, presence: true, inclusion: { in: PROVIDERS }
    validates :user_id, uniqueness: { scope: :provider }

    before_validation :ensure_uuid, on: :create

    private

    def ensure_uuid
      self.uuid ||= SecureRandom.uuid
    end
  end
end
