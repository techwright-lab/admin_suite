# frozen_string_literal: true

module Assistant
  module Memory
    class ThreadSummary < ApplicationRecord
      self.table_name = "assistant_thread_summaries"

      include Assistant::HasUuid

      belongs_to :thread, class_name: "Assistant::ChatThread"
      belongs_to :last_summarized_message, class_name: "Assistant::ChatMessage", optional: true
      belongs_to :llm_api_log, class_name: "Ai::LlmApiLog", optional: true
    end
  end
end
