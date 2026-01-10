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

      # Build page context from params
      # This allows the frontend to indicate which page the user is on,
      # enabling context-aware features like including full resume text
      page_context = build_page_context_from_params

      # Create user message immediately
      trace_id = SecureRandom.uuid
      @user_message = @thread.messages.create!(
        role: "user",
        content: question,
        metadata: { trace_id: trace_id, page_context: page_context }
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

    # Builds page context from request parameters
    #
    # Supported context fields:
    # - resume_id: User is viewing a resume (triggers full resume text inclusion)
    # - job_listing_id: User is viewing a job listing
    # - interview_application_id: User is viewing an application
    # - opportunity_id: User is viewing an opportunity
    # - include_full_resume: Explicit flag to include full resume text
    #
    # @return [Hash] Page context for the assistant
    def build_page_context_from_params
      context = {}

      # Extract context IDs from params
      context[:resume_id] = params[:resume_id].to_i if params[:resume_id].present?
      context[:job_listing_id] = params[:job_listing_id].to_i if params[:job_listing_id].present?
      context[:interview_application_id] = params[:interview_application_id].to_i if params[:interview_application_id].present?
      context[:opportunity_id] = params[:opportunity_id].to_i if params[:opportunity_id].present?

      # Explicit flags
      context[:include_full_resume] = true if params[:include_full_resume] == "true" || params[:include_full_resume] == true

      context.compact
    end

    # Unlocks the insight-triggered trial on the user's first AI assistant request.
    #
    # @return [void]
    def maybe_unlock_insight_trial_after_first_ai_request
      result = Billing::TrialUnlockService.new(user: Current.user, trigger: :first_ai_request).run
      return unless result[:unlocked]

      flash.now[:notice] = "You've unlocked Pro insights for 72 hours."
    end
  end
end
