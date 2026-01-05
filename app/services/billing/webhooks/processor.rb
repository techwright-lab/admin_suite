# frozen_string_literal: true

module Billing
  module Webhooks
    # Routes webhook events to a provider-specific processor.
    class Processor
      # @param webhook_event [Billing::WebhookEvent]
      def initialize(webhook_event)
        @webhook_event = webhook_event
      end

      # @return [void]
      def run
        case webhook_event.provider
        when "lemonsqueezy"
          Billing::Webhooks::LemonSqueezyProcessor.new(webhook_event).run
        else
          webhook_event.update!(status: "ignored", processed_at: Time.current)
        end
      end

      private

      attr_reader :webhook_event
    end
  end
end


