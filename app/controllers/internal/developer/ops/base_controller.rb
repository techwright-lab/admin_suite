# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      # Base controller for the Ops Portal
      class BaseController < Internal::Developer::BaseController
        helper_method :current_portal

        private

        def current_portal
          :ops
        end

        def portal_resources
          Admin::Base::Resource.resources_for_portal(:ops)
        end
      end
    end
  end
end

