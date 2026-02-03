# frozen_string_literal: true

class IncreaseGenerateInterviewPrepToolTimeout < ActiveRecord::Migration[8.1]
  class AssistantTool < ActiveRecord::Base
    self.table_name = "assistant_tools"
  end

  def up
    # Generating multiple interview prep artifacts can involve multiple LLM calls and exceed 60s.
    AssistantTool.where(tool_key: "generate_interview_prep").update_all(timeout_ms: 180_000, updated_at: Time.current)
  end

  def down
    AssistantTool.where(tool_key: "generate_interview_prep").update_all(timeout_ms: 60_000, updated_at: Time.current)
  end
end
