# frozen_string_literal: true

class AddMetadataToAssistantToolExecutions < ActiveRecord::Migration[8.1]
  def change
    add_column :assistant_tool_executions, :metadata, :jsonb, default: {}, null: false
    add_index :assistant_tool_executions, :metadata, using: :gin
  end
end
