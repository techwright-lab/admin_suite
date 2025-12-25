# frozen_string_literal: true

module Internal
  module Developer
    module Ai
      class LlmProviderConfigsController < Internal::Developer::ResourcesController
        # POST /internal/developer/ai/llm_provider_configs/:id/toggle
        def toggle
          @resource.update!(enabled: !@resource.enabled)

          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.replace(
                dom_id(@resource, :toggle),
                partial: "internal/developer/shared/toggle_cell",
                locals: { record: @resource, field: :enabled }
              )
            end
            format.html { redirect_to resource_url(@resource), notice: "Provider #{@resource.enabled? ? 'enabled' : 'disabled'}." }
          end
        end

        # POST /internal/developer/ai/llm_provider_configs/:id/enable
        def enable
          @resource.update!(enabled: true)
          redirect_to resource_url(@resource), notice: "Provider enabled."
        end

        # POST /internal/developer/ai/llm_provider_configs/:id/disable
        def disable
          @resource.update!(enabled: false)
          redirect_to resource_url(@resource), notice: "Provider disabled."
        end

        private

        def resource_config
          Admin::Resources::LlmProviderConfigResource
        end

        def current_portal
          :ai
        end
      end
    end
  end
end

