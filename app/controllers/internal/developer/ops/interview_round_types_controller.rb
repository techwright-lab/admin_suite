# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      # InterviewRoundTypes controller for the Ops Portal
      #
      # Provides CRUD and toggle operations for managing interview round types.
      class InterviewRoundTypesController < Internal::Developer::ResourcesController
        # POST /internal/developer/ops/interview_round_types/:id/disable
        def disable
          @resource.disable!
          redirect_to resource_url(@resource), notice: "Round type disabled."
        end

        # POST /internal/developer/ops/interview_round_types/:id/enable
        def enable
          @resource.enable!
          redirect_to resource_url(@resource), notice: "Round type enabled."
        end

        # POST /internal/developer/ops/interview_round_types/:id/toggle
        def toggle
          if @resource.disabled?
            @resource.enable!
            redirect_to resource_url(@resource), notice: "Round type enabled."
          else
            @resource.disable!
            redirect_to resource_url(@resource), notice: "Round type disabled."
          end
        end

        private

        def current_portal
          :ops
        end

        def resource_config
          Admin::Resources::InterviewRoundTypeResource
        end
      end
    end
  end
end
