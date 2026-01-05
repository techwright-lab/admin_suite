# frozen_string_literal: true

module Internal
  module Developer
    module Payments
      # Webhook events controller for the Payments Portal (read-only + replay).
      class WebhookEventsController < Internal::Developer::ResourcesController
        # POST /internal/developer/payments/webhook_events/:id/replay
        def replay
          @resource.update!(status: "pending", processed_at: nil, error_message: nil)
          Billing::ProcessWebhookEventJob.perform_later(@resource)
          redirect_to resource_url(@resource), notice: "Webhook event replay enqueued."
        end

        private

        def current_portal
          :payments
        end

        def resource_config
          Admin::Resources::BillingWebhookEventResource
        end
      end
    end
  end
end


