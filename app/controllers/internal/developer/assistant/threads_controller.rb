# frozen_string_literal: true

module Internal
  module Developer
    module Assistant
      # Threads controller for the Assistant Portal
      class ThreadsController < Internal::Developer::ResourcesController
        def export
          respond_to do |format|
            format.json { render json: @resource }
          end
        end

        private

        def current_portal
          :assistant
        end

        def resource_config
          Admin::Resources::AssistantThreadResource
        end
      end
    end
  end
end

