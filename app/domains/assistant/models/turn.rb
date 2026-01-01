# frozen_string_literal: true

module Assistant
  # A single assistant turn: user message -> assistant response (+ tools).
  class Turn < ApplicationRecord
    self.table_name = "assistant_turns"

    include Assistant::HasUuid

    STATUSES = %w[success error].freeze
    PROVIDERS = %w[openai anthropic ollama].freeze

    belongs_to :thread,
      class_name: "Assistant::ChatThread",
      foreign_key: :thread_id,
      inverse_of: :turns

    belongs_to :user_message,
      class_name: "Assistant::ChatMessage"

    belongs_to :assistant_message,
      class_name: "Assistant::ChatMessage"

    belongs_to :llm_api_log,
      class_name: "Ai::LlmApiLog"

    validates :trace_id, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :provider_name, inclusion: { in: PROVIDERS }, allow_blank: true

    def to_param
      uuid
    end
  end
end
