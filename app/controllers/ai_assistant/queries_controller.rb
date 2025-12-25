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

      if question.blank?
        render json: { error: "Question cannot be blank" }, status: :unprocessable_entity
        return
      end

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
        client_request_uuid: client_request_uuid
      ).call

      render json: {
        answer: result[:assistant_message].content,
        thread_id: result[:thread].id,
        thread_uuid: result[:thread].uuid,
        trace_id: result[:trace_id],
        tool_calls: result[:tool_calls]
      }
    end
  end
end
