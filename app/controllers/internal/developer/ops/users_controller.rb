# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      class UsersController < Internal::Developer::ResourcesController
        private

        def resource_config
          Admin::Resources::UserResource
        end

        def current_portal
          :ops
        end
      end
    end
  end
end

