# frozen_string_literal: true

module Internal
  module Developer
    module Email
      # Base controller for the Email Portal.
      class BaseController < Internal::Developer::BaseController
        helper_method :current_portal

        private

        def current_portal
          :email
        end

        def portal_resources
          Admin::Base::Resource.resources_for_portal(:email)
        end
      end
    end
  end
end
