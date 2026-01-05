# frozen_string_literal: true

module Assistant
  # POST /assistant/threads/:thread_uuid/messages
  #
  # Creates a user message immediately and enqueues async LLM processing.
  # Returns turbo_stream with user message + thinking indicator.
  class MessagesController < ApplicationController
    def create
      @thread = ChatThread.where(user: Current.user).find_by!(uuid: params[:thread_uuid])
      question = params[:content].to_s.strip
      client_request_uuid = params[:client_request_uuid].presence

      if question.blank?
        head :unprocessable_entity
        return
      end

      # Check for duplicate request (idempotency)
      if client_request_uuid.present?
        existing_turn = Assistant::Turn.where(thread: @thread, client_request_uuid: client_request_uuid).first
        if existing_turn
          @user_message = existing_turn.user_message
          @assistant_message = existing_turn.assistant_message
          @show_thinking = false
          respond_to do |format|
            format.turbo_stream
            format.html { redirect_to assistant_thread_path(@thread) }
          end
          return
        end
      end

      # Create user message immediately
      trace_id = SecureRandom.uuid
      @user_message = @thread.messages.create!(
        role: "user",
        content: question,
        metadata: { trace_id: trace_id }
      )

      # Update thread activity
      @thread.update!(last_activity_at: Time.current)

      # Auto-generate title from first message if thread has no title
      if @thread.title.blank? && @thread.messages.where(role: "user").count == 1
        @thread.update!(title: question.truncate(50))
      end

      # Enqueue async LLM processing
      @trace_id = trace_id
      AssistantChatJob.perform_later(
        thread_id: @thread.id,
        user_id: Current.user.id,
        user_message_id: @user_message.id,
        trace_id: trace_id,
        client_request_uuid: client_request_uuid
      )

      @show_thinking = true
      maybe_unlock_insight_trial_after_first_ai_request

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to assistant_thread_path(@thread) }
      end
    end

    private

    # Unlocks the insight-triggered trial on the user's first AI assistant request.
    #
    # @return [void]
    def maybe_unlock_insight_trial_after_first_ai_request
      result = Billing::TrialUnlockService.new(user: Current.user, trigger: :first_ai_request).run
      return unless result[:unlocked]

      flash.now[:notice] = "You’ve unlocked Pro insights for 72 hours."
    end
  end
end
