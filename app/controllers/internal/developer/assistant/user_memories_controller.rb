# frozen_string_literal: true

module Internal
  module Developer
    module Assistant
      class UserMemoriesController < Internal::Developer::ResourcesController
        private

        def resource_config
          Admin::Resources::AssistantUserMemoryResource
        end

        def current_portal
          :assistant
        end
      end
    end
  end
end

