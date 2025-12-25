# frozen_string_literal: true

require "securerandom"

module Assistant
  module Chat
    # Orchestrates a single assistant turn:
    # - persists user message
    # - builds context snapshot
    # - calls LLM (with fallback providers)
    # - persists assistant message + turn record
    # - records proposed tool executions (not executed here)
    class Orchestrator
      def initialize(user:, thread: nil, message:, page_context: {}, client_request_uuid: nil)
        @user = user
        @thread = thread
        @message = message.to_s
        @page_context = page_context.to_h
        @client_request_uuid = client_request_uuid.presence
      end

      def call
        raise ArgumentError, "message is blank" if message.strip.blank?

        if client_request_uuid.present? && thread.present?
          existing = Assistant::Turn.where(thread: thread, client_request_uuid: client_request_uuid).first
          if existing
            return {
              thread: thread,
              user_message: existing.user_message,
              assistant_message: existing.assistant_message,
              trace_id: existing.trace_id,
              tool_calls: Array(existing.assistant_message.metadata["tool_calls"] || existing.assistant_message.metadata[:tool_calls]),
              tool_executions: Assistant::ToolExecution.where(thread: thread, assistant_message_id: existing.assistant_message_id).order(created_at: :asc)
            }
          end
        end

        result = ActiveRecord::Base.transaction do
          ensure_thread!
          trace_id = SecureRandom.uuid

          user_msg = thread.messages.create!(
            role: "user",
            content: message,
            metadata: { trace_id: trace_id, page_context: page_context }
          )

          context = Assistant::Context::Builder.new(user: user, page_context: page_context).build
          allowed_tools = Assistant::ToolPolicy.new(user: user, thread: thread, page_context: page_context).allowed_tools

          llm_result = Assistant::Chat::Components::LlmResponder.new(
            user: user,
            trace_id: trace_id,
            question: message,
            context: context,
            allowed_tools: allowed_tools,
            thread: thread
          ).call

          assistant_msg = thread.messages.create!(
            role: "assistant",
            content: llm_result.fetch(:answer),
            metadata: llm_result.fetch(:metadata)
          )

          thread.update!(last_activity_at: Time.current) if thread.last_activity_at.nil? || thread.last_activity_at < Time.current

          Assistant::Turn.create!(
            thread: thread,
            user_message: user_msg,
            assistant_message: assistant_msg,
            trace_id: trace_id,
            context_snapshot: context,
            llm_api_log: llm_result.fetch(:llm_api_log),
            latency_ms: llm_result[:latency_ms],
            status: llm_result[:status] || "success",
            client_request_uuid: client_request_uuid
          )

          created_tool_executions = Assistant::Chat::Components::ToolProposalRecorder.new(
            trace_id: trace_id,
            assistant_message: assistant_msg,
            tool_calls: llm_result[:tool_calls] || []
          ).call

          {
            thread: thread,
            user_message: user_msg,
            assistant_message: assistant_msg,
            trace_id: trace_id,
            tool_calls: llm_result[:tool_calls] || [],
            tool_executions: created_tool_executions
          }
        end

        # Async background work (does not block response):
        # - summarization (only runs when threshold met)
        # - memory proposals (always user-confirmed)
        AssistantThreadSummarizerJob.perform_later(result[:thread].id)
        AssistantMemoryProposerJob.perform_later(user.id, result[:thread].id, result[:trace_id])

        # Auto-enqueue non-confirmation tools (read-only) for async execution.
        Array(result[:tool_executions]).each do |tool_execution|
          next if tool_execution.requires_confirmation

          tool_execution.update!(status: "queued") if tool_execution.status == "proposed"
          AssistantToolExecutionJob.perform_later(tool_execution.id)
        end

        result
      end

      private

      attr_reader :user, :thread, :message, :page_context, :client_request_uuid

      def ensure_thread!
        @thread ||= Assistant::ChatThread.create!(user: user, title: nil, last_activity_at: Time.current, status: "open")
      end

      # LLM/tool proposal logic extracted into Assistant::Chat::Components::*
    end
  end
end
