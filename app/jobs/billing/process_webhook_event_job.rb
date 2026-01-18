# frozen_string_literal: true

module Billing
  # Processes a stored billing webhook event asynchronously.
  class ProcessWebhookEventJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    # @param webhook_event [Billing::WebhookEvent]
    def perform(webhook_event)
      webhook_event = Billing::WebhookEvent.find(webhook_event.id) unless webhook_event.is_a?(Billing::WebhookEvent)
      return unless webhook_event.status == "pending"

      processor = Billing::Webhooks::Processor.new(webhook_event)
      processor.run
    rescue StandardError => e
      handle_error(e,
        context: "billing_webhook_processing",
        webhook_event_id: webhook_event&.id,
        provider: webhook_event&.provider,
        event_type: webhook_event&.event_type
      )
    end
  end
end
