# frozen_string_literal: true

module Internal
  module Developer
    module Ai
      class LlmApiLogsController < Internal::Developer::ResourcesController
        private

        def resource_config
          Admin::Resources::LlmApiLogResource
        end

        def current_portal
          :ai
        end
      end
    end
  end
end

