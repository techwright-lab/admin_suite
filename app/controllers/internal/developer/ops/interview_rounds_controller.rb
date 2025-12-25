# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      # InterviewRounds controller for the Ops Portal
      class InterviewRoundsController < Internal::Developer::ResourcesController
        private

        def current_portal
          :ops
        end

        def resource_config
          Admin::Resources::InterviewRoundResource
        end
      end
    end
  end
end

