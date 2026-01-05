# frozen_string_literal: true

module Internal
  module Developer
    module Payments
      # Plans controller for the Payments Portal.
      class PlansController < Internal::Developer::ResourcesController
        private

        def current_portal
          :payments
        end

        def resource_config
          Admin::Resources::BillingPlanResource
        end
      end
    end
  end
end


