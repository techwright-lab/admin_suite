# frozen_string_literal: true

module Assistant
  class ToolExecutionsController < ApplicationController
    def approve
      tool_execution = scoped.find_by!(uuid: params[:uuid])

      if tool_execution.requires_confirmation? == false
        redirect_back fallback_location: assistant_thread_path(tool_execution.thread), alert: "This tool does not require approval."
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
      redirect_back fallback_location: assistant_thread_path(tool_execution.thread), notice: (enqueued ? "Approved and enqueued." : "Already running or finished.")
    end

    def enqueue
      tool_execution = scoped.find_by!(uuid: params[:uuid])

      if tool_execution.requires_confirmation? && tool_execution.approved_by_id.nil?
        redirect_back fallback_location: assistant_thread_path(tool_execution.thread), alert: "This tool requires approval before it can be executed."
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
      redirect_back fallback_location: assistant_thread_path(tool_execution.thread), notice: (enqueued ? "Enqueued." : "Already queued or processed.")
    end

    private

    def scoped
      ::Assistant::ToolExecution.joins(:thread).where(assistant_threads: { user_id: Current.user.id })
    end
  end
end
