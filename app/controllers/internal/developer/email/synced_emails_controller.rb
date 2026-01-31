# frozen_string_literal: true

module Internal
  module Developer
    module Email
      class SyncedEmailsController < Internal::Developer::ResourcesController
        private

        def resource_config
          Admin::Resources::SyncedEmailResource
        end

        def current_portal
          :email
        end
      end
    end
  end
end
