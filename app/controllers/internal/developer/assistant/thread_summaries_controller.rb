# frozen_string_literal: true

module Internal
  module Developer
    module Assistant
      class ThreadSummariesController < Internal::Developer::ResourcesController
        private

        def resource_config
          Admin::Resources::AssistantThreadSummaryResource
        end

        def current_portal
          :assistant
        end
      end
    end
  end
end

