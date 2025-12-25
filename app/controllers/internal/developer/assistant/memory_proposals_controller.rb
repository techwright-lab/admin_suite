# frozen_string_literal: true

module Internal
  module Developer
    module Assistant
      class MemoryProposalsController < Internal::Developer::ResourcesController
        private

        def resource_config
          Admin::Resources::AssistantMemoryProposalResource
        end

        def current_portal
          :assistant
        end
      end
    end
  end
end

