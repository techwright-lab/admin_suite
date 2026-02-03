# frozen_string_literal: true

module AiAssistant
  # Controller for handling AI assistant queries
  class QueriesController < ApplicationController
    # POST /ai_assistant/ask
    def ask
      question = params[:question]
      thread_uuid = params[:thread_uuid]
      thread_id = params[:thread_id]
      client_request_uuid = params[:client_request_uuid].presence
      page_context = build_page_context_from_params

      if question.blank?
        render json: { error: "Question cannot be blank" }, status: :unprocessable_entity
        return
      end

      trial_result = Billing::TrialUnlockService.new(user: Current.user, trigger: :first_ai_request).run

      thread =
        if thread_uuid.present?
          Assistant::ChatThread.where(user: Current.user).find_by(uuid: thread_uuid)
        elsif thread_id.present?
          Assistant::ChatThread.where(user: Current.user).find_by(id: thread_id)
        end
      result = Assistant::Chat::Orchestrator.new(
        user: Current.user,
        thread: thread,
        message: question,
        page_context: page_context,
        client_request_uuid: client_request_uuid
      ).call

      render json: {
        answer: result[:assistant_message].content,
        thread_id: result[:thread].id,
        thread_uuid: result[:thread].uuid,
        trace_id: result[:trace_id],
        tool_calls: result[:tool_calls],
        trial_unlocked: trial_result[:unlocked] == true,
        trial_expires_at: trial_result[:expires_at]
      }
    end

    private

    # Builds page context from request parameters
    #
    # @return [Hash] Page context for the assistant
    def build_page_context_from_params
      context = {}

      context[:resume_id] = params[:resume_id].to_i if params[:resume_id].present?
      context[:job_listing_id] = params[:job_listing_id].to_i if params[:job_listing_id].present?
      if params[:interview_application_id].present?
        raw = params[:interview_application_id].to_s.strip
        if raw.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
          context[:interview_application_uuid] = raw
        elsif raw.match?(/\A\d+\z/)
          context[:interview_application_id] = raw.to_i
        else
          context[:interview_application_uuid] = raw
        end
      end
      context[:opportunity_id] = params[:opportunity_id].to_i if params[:opportunity_id].present?
      context[:include_full_resume] = true if params[:include_full_resume] == "true" || params[:include_full_resume] == true

      context.compact
    end
  end
end
