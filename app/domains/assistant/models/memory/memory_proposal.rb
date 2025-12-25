# frozen_string_literal: true

module Assistant
  module Memory
    class MemoryProposal < ApplicationRecord
      self.table_name = "assistant_memory_proposals"

      include Assistant::HasUuid

      STATUSES = %w[pending accepted rejected expired].freeze

      belongs_to :thread, class_name: "Assistant::ChatThread"
      belongs_to :user
      belongs_to :llm_api_log, class_name: "Ai::LlmApiLog", optional: true
      belongs_to :confirmed_by, class_name: "User", optional: true

      validates :status, inclusion: { in: STATUSES }
    end
  end
end
