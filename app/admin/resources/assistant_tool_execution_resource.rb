# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Assistant Tool Execution admin management
    #
    # Provides operations to view, approve, enqueue, and replay tool executions.
    class AssistantToolExecutionResource < Admin::Base::Resource
      model ::Assistant::ToolExecution
      portal :assistant
      section :tools

      index do
        sortable :created_at, default: :created_at
        paginate 30

        stats do
          stat :total, -> { ::Assistant::ToolExecution.count }
          stat :proposed, -> { ::Assistant::ToolExecution.where(status: "proposed").count }, color: :slate
          stat :queued, -> { ::Assistant::ToolExecution.where(status: "queued").count }, color: :blue
          stat :running, -> { ::Assistant::ToolExecution.where(status: "running").count }, color: :amber
          stat :success, -> { ::Assistant::ToolExecution.where(status: "success").count }, color: :green
          stat :error, -> { ::Assistant::ToolExecution.where(status: "error").count }, color: :red
          stat :confirmation_required, -> { ::Assistant::ToolExecution.where(requires_confirmation: true).count }, color: :purple
        end

        columns do
          column :created_at, ->(te) { te.created_at.strftime("%b %d, %H:%M") }, header: "Time"
          column :tool_key, header: "Tool"
          column :status
          column :requires_confirmation, ->(te) { te.requires_confirmation? ? "Required" : "No" }, header: "Confirmation"
          column :trace_id, ->(te) { te.trace_id&.truncate(12) }
        end

        filters do
          filter :status, type: :select, options: [
            [ "All Statuses", "" ],
            [ "Proposed", "proposed" ],
            [ "Queued", "queued" ],
            [ "Running", "running" ],
            [ "Success", "success" ],
            [ "Error", "error" ]
          ]
          filter :requires_confirmation, type: :select, label: "Confirmation", options: [
            [ "All", "" ],
            [ "Required", "true" ],
            [ "Not Required", "false" ]
          ]
          filter :tool_key, type: :text, placeholder: "Tool key..."
          filter :trace_id, type: :text, placeholder: "Trace ID..."
        end
      end

      show do
        sidebar do
          panel :status, title: "Status", fields: [ :status, :requires_confirmation ]
          panel :approval, title: "Approval", fields: [ :approved_by, :approved_at ]
          panel :timing, title: "Timing", fields: [ :started_at, :finished_at, :duration_seconds, :created_at ]
          panel :thread, title: "Chat Thread",
                association: :chat_thread,
                display: :card,
                link_to: :internal_developer_assistant_thread_path
        end

        main do
          panel :tool, title: "Tool Information", fields: [ :tool_key, :trace_id, :provider_name, :provider_tool_call_id ]
          panel :data, title: "Arguments & Result", render: :tool_args_preview
        end
      end

      actions do
        action :approve, method: :post, label: "Approve",
               if: ->(te) { te.requires_confirmation && te.approved_by_id.nil? && te.status == "proposed" }
        action :enqueue, method: :post, label: "Enqueue",
               if: ->(te) { te.status == "proposed" && (!te.requires_confirmation || te.approved_by_id.present?) }
        action :replay, method: :post, label: "Replay",
               if: ->(te) { %w[success error].include?(te.status) }

        bulk_action :bulk_approve, label: "Approve Selected"
        bulk_action :bulk_enqueue, label: "Enqueue Selected"
      end

      exportable :json
    end
  end
end
