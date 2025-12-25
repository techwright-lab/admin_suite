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

    # Check for existing turn (idempotency)
    if client_request_uuid.present?
      existing_turn = Assistant::Turn.where(thread: thread, client_request_uuid: client_request_uuid).first
      if existing_turn&.assistant_message.present?
        broadcast_assistant_message(thread, existing_turn.assistant_message, trace_id)
        return
      end
    end

    begin
      result = process_llm_response(user, thread, user_message, trace_id, client_request_uuid)
      broadcast_assistant_message(thread, result[:assistant_message], trace_id)
      broadcast_tool_executions(thread) if result[:tool_executions].present?
    rescue StandardError => e
      Rails.logger.error("[AssistantChatJob] Error processing message: #{e.message}")
      broadcast_error_message(thread, trace_id, e.message)
    end
  end

  private

  def process_llm_response(user, thread, user_message, trace_id, client_request_uuid)
    context = Assistant::Context::Builder.new(user: user, page_context: {}).build
    allowed_tools = Assistant::ToolPolicy.new(user: user, thread: thread, page_context: {}).allowed_tools

    llm_result = Assistant::Chat::Components::LlmResponder.new(
      user: user,
      trace_id: trace_id,
      question: user_message.content,
      context: context,
      allowed_tools: allowed_tools,
      thread: thread
    ).call

    assistant_message = thread.messages.create!(
      role: "assistant",
      content: llm_result.fetch(:answer),
      metadata: llm_result.fetch(:metadata).merge(trace_id: trace_id)
    )

    turn = Assistant::Turn.create!(
      thread: thread,
      user_message: user_message,
      assistant_message: assistant_message,
      trace_id: trace_id,
      context_snapshot: context,
      llm_api_log: llm_result.fetch(:llm_api_log),
      latency_ms: llm_result[:latency_ms],
      status: llm_result[:status] || "success",
      client_request_uuid: client_request_uuid
    )

    tool_executions = Assistant::Chat::Components::ToolProposalRecorder.new(
      trace_id: trace_id,
      assistant_message: assistant_message,
      tool_calls: llm_result[:tool_calls] || []
    ).call

    # Auto-enqueue non-confirmation tools for async execution
    Array(tool_executions).each do |tool_execution|
      next if tool_execution.requires_confirmation

      tool_execution.update!(status: "queued") if tool_execution.status == "proposed"
      AssistantToolExecutionJob.perform_later(tool_execution.id)
    end

    # Enqueue background jobs
    AssistantThreadSummarizerJob.perform_later(thread.id)
    AssistantMemoryProposerJob.perform_later(user.id, thread.id, trace_id)

    {
      assistant_message: assistant_message,
      turn: turn,
      tool_executions: tool_executions
    }
  end

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
    tool_proposals = tool_executions.select { |te| te.status == "proposed" }

    Turbo::StreamsChannel.broadcast_replace_to(
      "assistant_thread_#{thread.id}",
      target: ActionView::RecordIdentifier.dom_id(thread, :tool_executions),
      partial: "assistant/threads/tool_executions_inline",
      locals: { thread: thread, tool_proposals: tool_proposals, tool_executions: tool_executions }
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

