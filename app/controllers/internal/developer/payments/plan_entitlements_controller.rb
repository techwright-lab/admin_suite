# frozen_string_literal: true

module Internal
  module Developer
    module Payments
      # Plan entitlements controller for the Payments Portal.
      class PlanEntitlementsController < Internal::Developer::ResourcesController
        private

        def current_portal
          :payments
        end

        def resource_config
          Admin::Resources::BillingPlanEntitlementResource
        end
      end
    end
  end
end


