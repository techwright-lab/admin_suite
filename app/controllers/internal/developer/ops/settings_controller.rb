# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      # Settings controller for the Ops Portal
      class SettingsController < Internal::Developer::ResourcesController
        # POST /internal/developer/ops/settings/:id/toggle
        def toggle
          @resource.update!(value: !@resource.value)

          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.replace(
                dom_id(@resource, :toggle),
                partial: "internal/developer/shared/toggle_cell",
                locals: { record: @resource, field: :value }
              )
            end
            format.html { redirect_to resource_url(@resource), notice: "Setting toggled." }
          end
        end

        private

        def resource_config
          Admin::Resources::SettingResource
        end

        def current_portal
          :ops
        end
      end
    end
  end
end

