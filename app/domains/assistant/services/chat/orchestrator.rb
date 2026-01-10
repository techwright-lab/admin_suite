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
      # @param user [User]
      # @param thread [Assistant::ChatThread, nil]
      # @param message [String]
      # @param page_context [Hash]
      # @param client_request_uuid [String, nil]
      # @param media [Array<Hash>, nil] Optional media attachments
      def initialize(user:, thread: nil, message:, page_context: {}, client_request_uuid: nil, media: nil)
        @user = user
        @thread = thread
        @message = message.to_s
        @page_context = page_context.to_h
        @client_request_uuid = client_request_uuid.presence
        @media = Array(media).compact
      end

      def call
        raise ArgumentError, "message is blank" if message.strip.blank?

        ensure_thread!
        trace_id = SecureRandom.uuid

        # Store media metadata in message for replay/debugging
        msg_metadata = { trace_id: trace_id, page_context: page_context }
        msg_metadata[:has_media] = true if media.present?
        msg_metadata[:media_types] = media.map { |m| m[:media_type] }.compact if media.present?

        user_msg = thread.messages.create!(
          role: "user",
          content: message,
          metadata: msg_metadata
        )

        Assistant::Chat::TurnRunner.new(
          user: user,
          thread: thread,
          user_message: user_msg,
          trace_id: trace_id,
          client_request_uuid: client_request_uuid,
          page_context: page_context,
          media: media
        ).call
      end

      private

      attr_reader :user, :thread, :message, :page_context, :client_request_uuid, :media

      def ensure_thread!
        @thread ||= Assistant::ChatThread.create!(user: user, title: nil, last_activity_at: Time.current, status: "open")
      end

      # LLM/tool proposal logic extracted into Assistant::Chat::Components::*
    end
  end
end
