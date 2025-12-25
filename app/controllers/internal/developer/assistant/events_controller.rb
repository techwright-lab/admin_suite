# frozen_string_literal: true

module Internal
  module Developer
    module Assistant
      class EventsController < Internal::Developer::ResourcesController
        private

        def resource_config
          Admin::Resources::AssistantEventResource
        end

        def current_portal
          :assistant
        end
      end
    end
  end
end

