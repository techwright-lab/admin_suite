# frozen_string_literal: true

module Billing
  # Stores LemonSqueezy order data for receipts and audit.
  class Order < ApplicationRecord
    self.table_name = "billing_orders"

    PROVIDERS = %w[lemonsqueezy].freeze

    belongs_to :user
    belongs_to :customer, class_name: "Billing::Customer", foreign_key: :billing_customer_id, optional: true
    belongs_to :subscription, class_name: "Billing::Subscription", foreign_key: :billing_subscription_id, optional: true

    validates :uuid, presence: true, uniqueness: true
    validates :provider, presence: true, inclusion: { in: PROVIDERS }
    validates :external_order_id, presence: true, uniqueness: { scope: :provider }

    before_validation :ensure_uuid, on: :create

    private

    # Ensures a UUID is assigned before validation.
    #
    # @return [void]
    def ensure_uuid
      self.uuid ||= SecureRandom.uuid
    end
  end
end
