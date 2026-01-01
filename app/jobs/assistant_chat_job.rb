# frozen_string_literal: true

# Processes an assistant chat message asynchronously.
# Called after user message is created, runs LLM and broadcasts result.
class AssistantChatJob < ApplicationJob
  queue_as :default

  # @param thread_id [Integer] the chat thread ID
  # @param user_id [Integer] the user ID
  # @param user_message_id [Integer] the user message ID
  # @param trace_id [String] the trace ID for this turn
  # @param client_request_uuid [String, nil] optional client request UUID for idempotency
  def perform(thread_id:, user_id:, user_message_id:, trace_id:, client_request_uuid: nil)
    thread = Assistant::ChatThread.find_by(id: thread_id)
    user = User.find_by(id: user_id)
    user_message = Assistant::ChatMessage.find_by(id: user_message_id)

    return unless thread && user && user_message

    begin
      result = Assistant::Chat::TurnRunner.new(
        user: user,
        thread: thread,
        user_message: user_message,
        trace_id: trace_id,
        client_request_uuid: client_request_uuid,
        page_context: user_message.metadata["page_context"] || {}
      ).call

      broadcast_assistant_message(thread, result[:assistant_message], trace_id)
      # Always broadcast tool action items, even if this turn deduped all tool calls and didn't create
      # new tool_executions. This keeps the UI consistent without requiring refresh.
      broadcast_tool_executions(thread)
    rescue StandardError => e
      Rails.logger.error("[AssistantChatJob] Error processing message: #{e.message}")
      Ai::ErrorReporter.notify(
        e,
        operation: :assistant_chat_job,
        provider: nil,
        model: nil,
        user: user,
        thread: thread,
        trace_id: trace_id,
        extra: { user_message_id: user_message.id }
      )
      broadcast_error_message(thread, trace_id, e.message)
    end
  end

  private

  def broadcast_assistant_message(thread, assistant_message, trace_id)
    # Remove thinking indicator and append assistant message
    Turbo::StreamsChannel.broadcast_remove_to(
      "assistant_thread_#{thread.id}",
      target: "thinking_#{trace_id}"
    )

    Turbo::StreamsChannel.broadcast_append_to(
      "assistant_thread_#{thread.id}",
      target: ActionView::RecordIdentifier.dom_id(thread, :messages),
      partial: "assistant/threads/message",
      locals: { message: assistant_message }
    )
  end

  def broadcast_tool_executions(thread)
    tool_executions = thread.tool_executions.order(created_at: :desc)
    tool_action_items = tool_executions.select { |te| te.status.in?(%w[proposed queued running]) }

    Turbo::StreamsChannel.broadcast_replace_to(
      "assistant_thread_#{thread.id}",
      target: ActionView::RecordIdentifier.dom_id(thread, :tool_executions),
      partial: "assistant/threads/tool_proposals",
      locals: { thread: thread, tool_executions: tool_action_items }
    )
  end

  def broadcast_error_message(thread, trace_id, error_message)
    # Remove thinking indicator
    Turbo::StreamsChannel.broadcast_remove_to(
      "assistant_thread_#{thread.id}",
      target: "thinking_#{trace_id}"
    )

    # Append error message
    Turbo::StreamsChannel.broadcast_append_to(
      "assistant_thread_#{thread.id}",
      target: ActionView::RecordIdentifier.dom_id(thread, :messages),
      partial: "assistant/threads/error_message",
      locals: { error_message: "Sorry, I encountered an issue processing your request. Please try again." }
    )
  end
end
