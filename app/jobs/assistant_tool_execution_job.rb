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

    # Persist canonical tool result message for reliable provider follow-ups (new turns going forward).
    Assistant::Chat::ToolResultMessagePersister.new(tool_execution: tool_execution).call

    broadcast_tool_executions(thread)

    enqueue_followup_if_ready(tool_execution)
  rescue StandardError => e
    Ai::ErrorReporter.notify(
      e,
      operation: :assistant_tool_execution_job,
      provider: tool_execution&.provider_name,
      model: nil,
      user: user,
      thread: thread,
      trace_id: tool_execution&.trace_id,
      extra: { tool_execution_id: tool_execution_id }
    )
    raise
  end

  private

  def broadcast_tool_executions(thread)
    tool_executions = thread.tool_executions.order(created_at: :desc)
    tool_action_items = tool_executions.select { |te| te.status.in?(%w[proposed queued running]) }

    Turbo::StreamsChannel.broadcast_replace_to(
      "assistant_thread_#{thread.id}",
      target: ActionView::RecordIdentifier.dom_id(thread, :tool_executions),
      partial: "assistant/threads/tool_proposals",
      locals: { thread: thread, tool_executions: tool_action_items }
    )
  rescue StandardError => e
    Ai::ErrorReporter.notify(
      e,
      operation: :assistant_tool_execution_broadcast,
      provider: nil,
      model: nil,
      user: thread.user,
      thread: thread,
      trace_id: nil
    )
  end

  def enqueue_followup_if_ready(tool_execution)
    thread = tool_execution.thread
    assistant_message_id = tool_execution.assistant_message_id

    return unless tool_execution.status.in?(%w[success error])

    pending = thread.tool_executions.where(assistant_message_id: assistant_message_id, status: %w[proposed queued running]).exists?
    return if pending

    AssistantToolFollowupJob.perform_later(assistant_message_id)
  rescue StandardError
    # best-effort only
  end
end
