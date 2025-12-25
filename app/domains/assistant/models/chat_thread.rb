# frozen_string_literal: true

module Assistant
  # A chat thread (conversation) for a single user.
  class ChatThread < ApplicationRecord
    self.table_name = "assistant_threads"

    include Assistant::HasUuid

    belongs_to :user

    has_many :messages,
      class_name: "Assistant::ChatMessage",
      foreign_key: :thread_id,
      dependent: :destroy,
      inverse_of: :thread

    has_many :turns,
      class_name: "Assistant::Turn",
      foreign_key: :thread_id,
      dependent: :destroy,
      inverse_of: :thread

    has_many :tool_executions,
      class_name: "Assistant::ToolExecution",
      foreign_key: :thread_id,
      dependent: :destroy,
      inverse_of: :thread

    has_one :summary,
      class_name: "Assistant::Memory::ThreadSummary",
      foreign_key: :thread_id,
      dependent: :destroy,
      inverse_of: :thread

    scope :recent_first, -> { order(last_activity_at: :desc, updated_at: :desc) }

    # Returns a display-friendly title for the thread.
    # Uses the explicit title if set, otherwise derives from first user message.
    #
    # @return [String] the display title
    def display_title
      return title if title.present?

      first_user_message = messages.where(role: "user").order(:created_at).first
      if first_user_message&.content.present?
        first_user_message.content.truncate(50)
      else
        "New conversation"
      end
    end

    # Returns a short version of the display title for sidebar links.
    #
    # @return [String] truncated title
    def short_title
      display_title.truncate(35)
    end
  end
end
