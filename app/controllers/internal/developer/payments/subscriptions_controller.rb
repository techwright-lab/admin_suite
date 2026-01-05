# frozen_string_literal: true

module Internal
  module Developer
    module Payments
      # Subscriptions controller for the Payments Portal (read-only).
      class SubscriptionsController < Internal::Developer::ResourcesController
        private

        def current_portal
          :payments
        end

        def resource_config
          Admin::Resources::BillingSubscriptionResource
        end
      end
    end
  end
end


