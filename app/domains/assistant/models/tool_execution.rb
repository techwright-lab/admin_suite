# frozen_string_literal: true

module Assistant
  # A single tool execution record (audit + observability).
  class ToolExecution < ApplicationRecord
    self.table_name = "assistant_tool_executions"

    include Assistant::HasUuid

    STATUSES = %w[proposed queued running success error cancelled].freeze

    belongs_to :thread,
      class_name: "Assistant::ChatThread",
      foreign_key: :thread_id,
      inverse_of: :tool_executions

    belongs_to :assistant_message,
      class_name: "Assistant::ChatMessage",
      inverse_of: false

    belongs_to :approved_by,
      class_name: "User",
      optional: true

    validates :tool_key, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :trace_id, presence: true
  end
end
