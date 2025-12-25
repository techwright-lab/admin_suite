# frozen_string_literal: true

module Assistant
  class WidgetsController < ApplicationController
    def show
      @thread = ChatThread.where(user: Current.user).order(last_activity_at: :desc, created_at: :desc).first
      @thread ||= ChatThread.create!(user: Current.user, title: nil, status: "open", last_activity_at: Time.current)

      @messages = @thread.messages.order(:created_at)
      @tool_executions = @thread.tool_executions.order(created_at: :desc)
      @tool_proposals = @tool_executions.select { |te| te.status == "proposed" }

      render layout: false
    end
  end
end
