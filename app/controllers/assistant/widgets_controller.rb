# frozen_string_literal: true

module Assistant
  # GET /assistant/widget
  # GET /assistant/widget/threads
  # POST /assistant/widget/new_thread
  #
  # Handles the floating assistant widget that appears across the app.
  class WidgetsController < ApplicationController
    # GET /assistant/widget
    # Shows a thread in the widget. If thread_uuid is provided, shows that thread.
    # Otherwise shows the most recent thread (or creates one).
    def show
      @thread = if params[:thread_uuid].present?
                  ChatThread.where(user: Current.user).find_by!(uuid: params[:thread_uuid])
                else
                  find_or_create_thread
                end
      load_thread_data
      render layout: false
    end

    # GET /assistant/widget/threads
    # Returns a list of recent threads for the thread switcher dropdown
    def threads
      @threads = ChatThread.where(user: Current.user)
                           .order(last_activity_at: :desc, created_at: :desc)
                           .limit(10)
      render layout: false
    end

    # POST /assistant/widget/new_thread
    # Creates a new thread and switches to it in the widget
    def new_thread
      @thread = ChatThread.create!(
        user: Current.user,
        title: nil,
        status: "open",
        last_activity_at: Time.current
      )
      load_thread_data
      render :show, layout: false
    end

    private

    def find_or_create_thread
      ChatThread.where(user: Current.user)
                .order(last_activity_at: :desc, created_at: :desc)
                .first ||
        ChatThread.create!(
          user: Current.user,
          title: nil,
          status: "open",
          last_activity_at: Time.current
        )
    end

    def load_thread_data
      @messages = @thread.messages.order(:created_at)
      @tool_executions = @thread.tool_executions.order(created_at: :desc)
      @tool_proposals = @tool_executions.select { |te| te.status == "proposed" }
    end
  end
end
