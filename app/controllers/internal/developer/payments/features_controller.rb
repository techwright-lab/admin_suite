# frozen_string_literal: true

module Internal
  module Developer
    module Payments
      # Features controller for the Payments Portal.
      class FeaturesController < Internal::Developer::ResourcesController
        private

        def current_portal
          :payments
        end

        def resource_config
          Admin::Resources::BillingFeatureResource
        end
      end
    end
  end
end


