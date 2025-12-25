# frozen_string_literal: true

module AiAssistant
  class ToolExecutionsController < ApplicationController
    # POST /ai_assistant/tool_executions/:id/enqueue
    def enqueue
      tool_execution = scoped_tool_executions.find(params[:id])

      if tool_execution.requires_confirmation && tool_execution.approved_by_id.nil?
        render json: { error: "This tool requires approval before it can be executed." }, status: :unprocessable_entity
        return
      end

      enqueued = false
      tool_execution.with_lock do
        if tool_execution.status == "proposed"
          tool_execution.update!(status: "queued")
          enqueued = true
        end
      end

      AssistantToolExecutionJob.perform_later(tool_execution.id) if enqueued

      render json: { status: tool_execution.status, tool_execution_id: tool_execution.id }
    end

    # POST /ai_assistant/tool_executions/:id/approve
    def approve
      tool_execution = scoped_tool_executions.find(params[:id])

      unless tool_execution.requires_confirmation
        render json: { error: "This tool does not require approval." }, status: :unprocessable_entity
        return
      end

      enqueued = false
      tool_execution.with_lock do
        if %w[success running].include?(tool_execution.status)
          # no-op
        else
          tool_execution.update!(
            approved_by: (tool_execution.approved_by || Current.user),
            approved_at: (tool_execution.approved_at || Time.current),
            status: (tool_execution.status == "proposed" ? "queued" : tool_execution.status)
          )
          enqueued = (tool_execution.status == "queued")
        end
      end

      AssistantToolExecutionJob.perform_later(tool_execution.id, approved_by_id: Current.user.id) if enqueued

      render json: { status: tool_execution.status, tool_execution_id: tool_execution.id }
    end

    private

    def scoped_tool_executions
      Assistant::ToolExecution.joins(:thread).where(assistant_threads: { user_id: Current.user.id })
    end
  end
end
