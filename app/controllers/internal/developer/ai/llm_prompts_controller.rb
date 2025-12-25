# frozen_string_literal: true

module Internal
  module Developer
    module Ai
      # LlmPrompts controller for the AI Portal
      class LlmPromptsController < Internal::Developer::ResourcesController
        # POST /internal/developer/ai/llm_prompts/:id/activate
        def activate
          if @resource.respond_to?(:activate!) && @resource.activate!
            redirect_to resource_url(@resource), notice: "Prompt activated."
          else
            redirect_to resource_url(@resource), alert: "Failed to activate prompt."
          end
        rescue => e
          redirect_to resource_url(@resource), alert: e.message
        end

        # POST /internal/developer/ai/llm_prompts/:id/duplicate
        def duplicate
          new_prompt = @resource.dup
          new_prompt.name = "#{@resource.name} (Copy)"
          new_prompt.active = false
          new_prompt.version = (@resource.version || 1) + 1

          if new_prompt.save
            redirect_to resource_url(new_prompt), notice: "Prompt duplicated successfully."
          else
            redirect_to resource_url(@resource), alert: "Failed to duplicate prompt."
          end
        end

        private

        def current_portal
          :ai
        end

        def resource_config
          Admin::Resources::LlmPromptResource
        end
      end
    end
  end
end

