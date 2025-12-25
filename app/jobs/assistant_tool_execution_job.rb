# frozen_string_literal: true

class AssistantToolExecutionJob < ApplicationJob
  queue_as :default

  def perform(tool_execution_id, approved_by_id: nil)
    tool_execution = Assistant::ToolExecution.find_by(id: tool_execution_id)
    return unless tool_execution

    thread = tool_execution.thread
    user = thread.user
    approved_by = approved_by_id.present? ? User.find_by(id: approved_by_id) : tool_execution.approved_by

    tool_execution.with_lock do
      return if tool_execution.status == "success"
      return if tool_execution.status == "running"

      if tool_execution.status == "proposed"
        tool_execution.update!(status: "queued")
      end
    end

    Assistant::Tools::Runner.new(user: user, tool_execution: tool_execution, approved_by: approved_by).call

    broadcast_tool_executions(thread)
  end

  private

  def broadcast_tool_executions(thread)
    tool_executions = thread.tool_executions.order(created_at: :desc)
    tool_proposals = tool_executions.select { |te| te.status == "proposed" }

    Turbo::StreamsChannel.broadcast_replace_to(
      "assistant_thread_#{thread.id}",
      target: ActionView::RecordIdentifier.dom_id(thread, :tool_executions),
      partial: "assistant/threads/tool_executions",
      locals: { thread: thread, tool_proposals: tool_proposals, tool_executions: tool_executions }
    )
  rescue StandardError
    # best-effort only
  end
end
