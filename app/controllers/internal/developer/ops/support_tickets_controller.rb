# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      class SupportTicketsController < Internal::Developer::ResourcesController
        private

        def resource_config
          Admin::Resources::SupportTicketResource
        end

        def current_portal
          :ops
        end
      end
    end
  end
end

