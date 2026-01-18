# frozen_string_literal: true

module Billing
  # A user's subscription state, synced from the payment provider via webhooks.
  class Subscription < ApplicationRecord
    self.table_name = "billing_subscriptions"

    PROVIDERS = %w[lemonsqueezy].freeze
    STATUSES = %w[active trialing cancelled expired past_due inactive].freeze

    belongs_to :user
    belongs_to :plan, class_name: "Billing::Plan", optional: true
    has_many :orders, class_name: "Billing::Order", foreign_key: :billing_subscription_id, dependent: :nullify

    store_accessor :urls,
      :customer_portal_url,
      :update_payment_method_url,
      :update_subscription_url,
      :latest_invoice_url,
      :latest_receipt_url

    validates :uuid, presence: true, uniqueness: true
    validates :provider, presence: true, inclusion: { in: PROVIDERS }
    validates :status, presence: true, inclusion: { in: STATUSES }

    before_validation :ensure_uuid, on: :create

    scope :active, -> { where(status: %w[active trialing]) }

    # @param at [Time]
    # @return [Boolean]
    def active_at?(at: Time.current)
      return true if status == "active"
      return true if status == "trialing" && trial_ends_at.present? && trial_ends_at > at

      current_period_ends_at.present? && current_period_ends_at > at
    end

    private

    def ensure_uuid
      self.uuid ||= SecureRandom.uuid
    end
  end
end
