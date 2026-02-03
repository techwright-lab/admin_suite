# frozen_string_literal: true

module Internal
  module Developer
    module Assistant
      # ToolExecutions controller for the Assistant Portal
      class ToolExecutionsController < Internal::Developer::ResourcesController
        # POST /internal/developer/assistant/tool_executions/:id/approve
        def approve
          actor = admin_suite_actor
          unless actor.is_a?(User)
            redirect_to resource_url(@resource), alert: "Approval requires an authenticated user actor."
            return
          end

          if @resource.requires_confirmation && @resource.approved_by_id.nil?
            @resource.update!(approved_by: actor, approved_at: Time.current)
            redirect_to resource_url(@resource), notice: "Tool execution approved."
          else
            redirect_to resource_url(@resource), alert: "Cannot approve this tool execution."
          end
        end

        # POST /internal/developer/assistant/tool_executions/:id/enqueue
        def enqueue
          if @resource.status == "proposed" && (!@resource.requires_confirmation || @resource.approved_by_id.present?)
            @resource.update!(status: "queued")
            redirect_to resource_url(@resource), notice: "Tool execution enqueued."
          else
            redirect_to resource_url(@resource), alert: "Cannot enqueue this tool execution."
          end
        end

        # POST /internal/developer/assistant/tool_executions/:id/replay
        def replay
          if %w[success error].include?(@resource.status)
            redirect_to resource_url(@resource), notice: "Tool execution replayed."
          else
            redirect_to resource_url(@resource), alert: "Cannot replay this tool execution."
          end
        end

        # POST /internal/developer/assistant/tool_executions/bulk_approve
        def bulk_approve
          ids = params[:ids] || []
          actor = admin_suite_actor
          unless actor.is_a?(User)
            redirect_to collection_url, alert: "Bulk approval requires an authenticated user actor."
            return
          end
          resource_class.where(id: ids, status: "proposed")
                        .where(requires_confirmation: true, approved_by_id: nil)
                        .update_all(approved_by_id: actor.id, approved_at: Time.current)
          redirect_to collection_url, notice: "Selected tool executions approved."
        end

        # POST /internal/developer/assistant/tool_executions/bulk_enqueue
        def bulk_enqueue
          ids = params[:ids] || []
          resource_class.where(id: ids, status: "proposed").update_all(status: "queued")
          redirect_to collection_url, notice: "Selected tool executions enqueued."
        end

        def export
          respond_to do |format|
            format.json { render json: @resource }
          end
        end

        private

        def current_portal
          :assistant
        end

        def resource_config
          Admin::Resources::AssistantToolExecutionResource
        end
      end
    end
  end
end
