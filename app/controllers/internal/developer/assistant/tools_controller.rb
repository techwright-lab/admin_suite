# frozen_string_literal: true

module Internal
  module Developer
    module Assistant
      class ToolsController < Internal::Developer::ResourcesController
        # POST /internal/developer/assistant/tools/:id/toggle
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
            format.html { redirect_to resource_url(@resource), notice: "Tool #{@resource.enabled? ? 'enabled' : 'disabled'}." }
          end
        end

        # POST /internal/developer/assistant/tools/:id/enable
        def enable
          @resource.update!(enabled: true)
          redirect_to resource_url(@resource), notice: "Tool enabled."
        end

        # POST /internal/developer/assistant/tools/:id/disable
        def disable
          @resource.update!(enabled: false)
          redirect_to resource_url(@resource), notice: "Tool disabled."
        end

        private

        def resource_config
          Admin::Resources::AssistantToolResource
        end

        def current_portal
          :assistant
        end
      end
    end
  end
end

