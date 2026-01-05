# frozen_string_literal: true

module Billing
  # Stores raw webhook events from payment providers for idempotency and replay.
  class WebhookEvent < ApplicationRecord
    self.table_name = "billing_webhook_events"

    PROVIDERS = %w[lemonsqueezy].freeze
    STATUSES = %w[pending processed failed ignored].freeze

    validates :uuid, presence: true, uniqueness: true
    validates :provider, presence: true, inclusion: { in: PROVIDERS }
    validates :idempotency_key, presence: true, uniqueness: { scope: :provider }
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :received_at, presence: true

    before_validation :ensure_uuid, on: :create

    scope :pending, -> { where(status: "pending") }

    private

    def ensure_uuid
      self.uuid ||= SecureRandom.uuid
    end
  end
end


