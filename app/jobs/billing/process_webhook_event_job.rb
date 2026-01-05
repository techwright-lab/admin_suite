# frozen_string_literal: true

module Billing
  # Processes a stored billing webhook event asynchronously.
  class ProcessWebhookEventJob < ApplicationJob
    queue_as :default

    # @param webhook_event [Billing::WebhookEvent]
    def perform(webhook_event)
      webhook_event = Billing::WebhookEvent.find(webhook_event.id) unless webhook_event.is_a?(Billing::WebhookEvent)
      return unless webhook_event.status == "pending"

      processor = Billing::Webhooks::Processor.new(webhook_event)
      processor.run
    end
  end
end


