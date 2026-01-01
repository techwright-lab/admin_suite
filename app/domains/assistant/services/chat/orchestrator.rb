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

        ensure_thread!
        trace_id = SecureRandom.uuid

        user_msg = thread.messages.create!(
          role: "user",
          content: message,
          metadata: { trace_id: trace_id, page_context: page_context }
        )

        Assistant::Chat::TurnRunner.new(
          user: user,
          thread: thread,
          user_message: user_msg,
          trace_id: trace_id,
          client_request_uuid: client_request_uuid,
          page_context: page_context
        ).call
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
