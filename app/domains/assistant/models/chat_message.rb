# frozen_string_literal: true

module Assistant
  # A message within a chat thread.
  class ChatMessage < ApplicationRecord
    self.table_name = "assistant_messages"

    include Assistant::HasUuid

    ROLES = %w[user assistant tool].freeze

    belongs_to :thread,
      class_name: "Assistant::ChatThread",
      foreign_key: :thread_id,
      inverse_of: :messages

    validates :role, presence: true, inclusion: { in: ROLES }
    validates :content, presence: true

    scope :chronological, -> { order(created_at: :asc) }
  end
end
