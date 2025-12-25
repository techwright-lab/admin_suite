# frozen_string_literal: true

module Internal
  module Developer
    module Assistant
      # Base controller for the Assistant Portal
      class BaseController < Internal::Developer::BaseController
        helper_method :current_portal

        private

        def current_portal
          :assistant
        end

        def portal_resources
          # Include both :ai and :assistant portal resources with assistant section
          Admin::Base::Resource.registered_resources.select do |r|
            r.section_name == :assistant
          end
        end
      end
    end
  end
end

