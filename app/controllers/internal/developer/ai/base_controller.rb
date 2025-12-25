# frozen_string_literal: true

module Internal
  module Developer
    module Ai
      # Base controller for the AI Portal
      class BaseController < Internal::Developer::BaseController
        helper_method :current_portal

        private

        def current_portal
          :ai
        end

        def portal_resources
          Admin::Base::Resource.resources_for_portal(:ai)
        end
      end
    end
  end
end

