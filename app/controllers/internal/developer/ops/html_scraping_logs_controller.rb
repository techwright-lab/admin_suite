# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      class HtmlScrapingLogsController < Internal::Developer::ResourcesController
        private

        def resource_config
          Admin::Resources::HtmlScrapingLogResource
        end

        def current_portal
          :ops
        end
      end
    end
  end
end

