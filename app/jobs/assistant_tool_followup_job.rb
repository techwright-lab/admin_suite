# frozen_string_literal: true

class AssistantToolFollowupJob < ApplicationJob
  queue_as :default

  # @param assistant_message_id [Integer] The assistant message that originated the tool calls.
  def perform(assistant_message_id)
    assistant_message = Assistant::ChatMessage.find_by(id: assistant_message_id)
    return unless assistant_message

    thread = assistant_message.thread
    user = thread.user

    thread.with_lock do
      # Only run follow-up for placeholder messages that are waiting on tool results.
      pending_followup = assistant_message.metadata["pending_tool_followup"] == true || assistant_message.metadata[:pending_tool_followup] == true
      return unless pending_followup

      pending = thread.tool_executions.where(assistant_message_id: assistant_message.id, status: %w[proposed queued running]).exists?
      return if pending
    end

    result = Assistant::Chat::Components::ToolFollowupResponder.new(
      user: user,
      thread: thread,
      originating_assistant_message: assistant_message
    ).call

    assistant_message.update!(
      content: result[:answer].to_s,
      metadata: assistant_message.metadata.merge(
        pending_tool_followup: false,
        tool_followup_completed_at: Time.current.iso8601
      )
    )

    broadcast_assistant_message_replace(thread, assistant_message)
  rescue StandardError => e
    Ai::ErrorReporter.notify(
      e,
      operation: :assistant_tool_followup_job,
      provider: (assistant_message&.metadata&.dig("provider") || assistant_message&.metadata&.dig(:provider)),
      model: (assistant_message&.metadata&.dig("model") || assistant_message&.metadata&.dig(:model)),
      user: user,
      thread: thread,
      trace_id: (assistant_message&.metadata&.dig("trace_id") || assistant_message&.metadata&.dig(:trace_id)),
      extra: { assistant_message_id: assistant_message_id }
    )
    raise
  end

  private

  def broadcast_assistant_message_replace(thread, assistant_message)
    Turbo::StreamsChannel.broadcast_replace_to(
      "assistant_thread_#{thread.id}",
      target: ActionView::RecordIdentifier.dom_id(assistant_message),
      partial: "assistant/threads/message",
      locals: { message: assistant_message }
    )
  rescue StandardError
    # best-effort only
  end
end
