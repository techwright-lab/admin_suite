# frozen_string_literal: true

module Internal
  module Developer
    module Payments
      # Dashboard for the Payments Portal.
      class DashboardController < Internal::Developer::BaseController
        before_action :load_resources!

        # GET /internal/developer/payments
        def index
          @stats = {
            plans: Billing::Plan.count,
            features: Billing::Feature.count,
            entitlements: Billing::PlanEntitlement.count,
            mappings: Billing::ProviderMapping.count,
            subscriptions: Billing::Subscription.count,
            webhook_events_pending: Billing::WebhookEvent.where(status: "pending").count
          }
        end

        private

        def current_portal
          :payments
        end
      end
    end
  end
end


