# frozen_string_literal: true

module AiAssistant
  # Controller for handling AI assistant queries
  class QueriesController < ApplicationController
    # POST /ai_assistant/ask
    def ask
      question = params[:question]

      if question.blank?
        render json: { error: "Question cannot be blank" }, status: :unprocessable_entity
        return
      end

      response = AiAssistantService.new(Current.user, question).answer

      render json: { answer: response }
    end
  end
end

