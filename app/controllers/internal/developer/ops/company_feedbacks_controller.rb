# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      # CompanyFeedbacks controller for the Ops Portal
      class CompanyFeedbacksController < Internal::Developer::ResourcesController
        private

        def current_portal
          :ops
        end

        def resource_config
          Admin::Resources::CompanyFeedbackResource
        end
      end
    end
  end
end

