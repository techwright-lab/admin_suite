# frozen_string_literal: true

module Assistant
  module Chat
    # Runs a single assistant turn given an already-persisted user message.
    #
    # Owns the core workflow:
    # - build context snapshot + allowed tools
    # - call LLM (with provider fallback)
    # - persist assistant message + Assistant::Turn
    # - record proposed tool executions
    # - enqueue read-only tool executions and background jobs
    #
    # This centralizes logic so controllers/jobs do not duplicate the LLM/tool flow.
    class TurnRunner
      # @param user [User]
      # @param thread [Assistant::ChatThread]
      # @param user_message [Assistant::ChatMessage] must be role="user"
      # @param trace_id [String]
      # @param client_request_uuid [String, nil]
      # @param page_context [Hash]
      def initialize(user:, thread:, user_message:, trace_id:, client_request_uuid: nil, page_context: {})
        @user = user
        @thread = thread
        @user_message = user_message
        @trace_id = trace_id.to_s
        @client_request_uuid = client_request_uuid.presence
        @page_context = page_context.to_h
      end

      # @return [Hash] { thread:, user_message:, assistant_message:, turn:, trace_id:, tool_calls:, tool_executions: }
      def call
        validate_inputs!

        existing = find_existing_turn
        return existing if existing

        result = run_transaction!

        enqueue_background_jobs(result)
        enqueue_auto_tools(result)

        result
      end

      private

      attr_reader :user, :thread, :user_message, :trace_id, :client_request_uuid, :page_context

      def validate_inputs!
        raise ArgumentError, "thread is required" if thread.nil?
        raise ArgumentError, "user is required" if user.nil?
        raise ArgumentError, "user_message is required" if user_message.nil?
        raise ArgumentError, "trace_id is required" if trace_id.blank?
      end

      def find_existing_turn
        return nil if client_request_uuid.blank?

        existing = Assistant::Turn.where(thread: thread, client_request_uuid: client_request_uuid).first
        return nil unless existing

        {
          thread: thread,
          user_message: existing.user_message,
          assistant_message: existing.assistant_message,
          turn: existing,
          trace_id: existing.trace_id,
          tool_calls: Array(existing.assistant_message&.metadata&.dig("tool_calls") || existing.assistant_message&.metadata&.dig(:tool_calls)),
          tool_executions: Assistant::ToolExecution.where(thread: thread, assistant_message_id: existing.assistant_message_id).order(created_at: :asc)
        }
      end

      def run_transaction!
        ActiveRecord::Base.transaction do
          context = Assistant::Context::Builder.new(user: user, page_context: page_context).build
          allowed_tools = Assistant::ToolPolicy.new(user: user, thread: thread, page_context: page_context).allowed_tools

          llm_result = Assistant::Chat::Components::LlmResponder.new(
            user: user,
            trace_id: trace_id,
            question: user_message.content,
            context: context,
            allowed_tools: allowed_tools,
            thread: thread
          ).call

          assistant_message = persist_assistant_message!(llm_result)
          turn = persist_turn!(assistant_message: assistant_message, context: context, llm_result: llm_result)
          tool_executions = persist_tool_executions!(assistant_message: assistant_message, llm_result: llm_result)

          {
            thread: thread,
            user_message: user_message,
            assistant_message: assistant_message,
            turn: turn,
            trace_id: trace_id,
            tool_calls: llm_result[:tool_calls] || [],
            tool_executions: tool_executions
          }
        end
      end

      def persist_assistant_message!(llm_result)
        thread.messages.create!(
          role: "assistant",
          content: llm_result.fetch(:answer),
          metadata: llm_result.fetch(:metadata).merge(trace_id: trace_id)
        ).tap do
          thread.update!(last_activity_at: Time.current) if thread.last_activity_at.nil? || thread.last_activity_at < Time.current
        end
      end

      def persist_turn!(assistant_message:, context:, llm_result:)
        provider_name = llm_result.dig(:metadata, :provider).to_s
        provider_state = (llm_result.dig(:metadata, :provider_state) || {}).dup

        # For OpenAI, any emitted tool call puts the response into an "awaiting tool outputs" state.
        # Until tool outputs are sent back (follow-up), we must not continue the conversation using
        # previous_response_id, otherwise OpenAI will 400 ("No tool output found for function call ...").
        if provider_name == "openai" && Array(llm_result[:tool_calls]).any?
          provider_state["awaiting_tool_outputs"] = true
        end

        Assistant::Turn.create!(
          thread: thread,
          user_message: user_message,
          assistant_message: assistant_message,
          trace_id: trace_id,
          context_snapshot: context,
          llm_api_log: llm_result.fetch(:llm_api_log),
          latency_ms: llm_result[:latency_ms],
          status: llm_result[:status] || "success",
          client_request_uuid: client_request_uuid,
          provider_name: provider_name.presence,
          provider_state: provider_state
        )
      end

      def persist_tool_executions!(assistant_message:, llm_result:)
        Assistant::Chat::Components::ToolProposalRecorder.new(
          trace_id: trace_id,
          assistant_message: assistant_message,
          tool_calls: llm_result[:tool_calls] || []
        ).call
      end

      def enqueue_background_jobs(result)
        AssistantThreadSummarizerJob.perform_later(result[:thread].id)
        AssistantMemoryProposerJob.perform_later(user.id, result[:thread].id, result[:trace_id])
      end

      def enqueue_auto_tools(result)
        Array(result[:tool_executions]).each do |tool_execution|
          next if tool_execution.requires_confirmation

          tool_execution.update!(status: "queued") if tool_execution.status == "proposed"
          AssistantToolExecutionJob.perform_later(tool_execution.id)
        end
      end
    end
  end
end
