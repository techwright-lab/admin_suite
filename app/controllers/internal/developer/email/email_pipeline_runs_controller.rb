# frozen_string_literal: true

module Internal
  module Developer
    module Email
      class EmailPipelineRunsController < Internal::Developer::ResourcesController
        private

        def resource_config
          Admin::Resources::EmailPipelineRunResource
        end

        def current_portal
          :email
        end
      end
    end
  end
end
