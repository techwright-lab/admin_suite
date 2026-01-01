class AddSystemPromptToLlmPrompts < ActiveRecord::Migration[8.1]
  def change
    add_column :llm_prompts, :system_prompt, :text
  end
end
