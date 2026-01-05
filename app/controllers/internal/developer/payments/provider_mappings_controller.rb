# frozen_string_literal: true

module Internal
  module Developer
    module Payments
      # Provider mappings controller for the Payments Portal.
      class ProviderMappingsController < Internal::Developer::ResourcesController
        private

        def current_portal
          :payments
        end

        def resource_config
          Admin::Resources::BillingProviderMappingResource
        end
      end
    end
  end
end


