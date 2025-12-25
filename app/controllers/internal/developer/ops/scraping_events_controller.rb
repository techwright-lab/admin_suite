# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      class ScrapingEventsController < Internal::Developer::ResourcesController
        private

        def resource_config
          Admin::Resources::ScrapingEventResource
        end

        def current_portal
          :ops
        end
      end
    end
  end
end

