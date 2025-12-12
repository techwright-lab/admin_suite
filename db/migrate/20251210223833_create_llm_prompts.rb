# frozen_string_literal: true

class CreateLlmPrompts < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_prompts do |t|
      # STI type column
      t.string :type, null: false

      # Basic info
      t.string :name, null: false
      t.text :description

      # Prompt content
      t.text :prompt_template, null: false

      # Variable definitions (for UI display and validation)
      # Example: { "url": { "required": true, "description": "Job listing URL" } }
      t.jsonb :variables, default: {}

      # Version management
      t.boolean :active, default: false, null: false
      t.integer :version, default: 1, null: false

      t.timestamps
    end

    # Indexes
    add_index :llm_prompts, :type
    add_index :llm_prompts, :active
    add_index :llm_prompts, :name
    add_index :llm_prompts, [ :type, :active ]
    add_index :llm_prompts, [ :type, :active, :version ]
  end
end
