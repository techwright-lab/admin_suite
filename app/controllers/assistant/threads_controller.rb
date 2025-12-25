# frozen_string_literal: true

module Assistant
  class ThreadsController < ApplicationController
    def index
      @threads = ChatThread.where(user: Current.user).order(last_activity_at: :desc, created_at: :desc)
    end

    def show
      @thread = ChatThread.where(user: Current.user).find_by!(uuid: params[:uuid])
      @messages = @thread.messages.order(:created_at)
      @tool_executions = @thread.tool_executions.order(created_at: :desc)
      @tool_proposals = @tool_executions.select { |te| te.status == "proposed" }
    end

    def create
      thread = ChatThread.create!(user: Current.user, title: nil, status: "open", last_activity_at: Time.current)
      redirect_to assistant_thread_path(thread)
    end
  end
end
