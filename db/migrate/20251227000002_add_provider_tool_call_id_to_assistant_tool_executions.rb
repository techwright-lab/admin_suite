# frozen_string_literal: true

class AddProviderToolCallIdToAssistantToolExecutions < ActiveRecord::Migration[8.1]
  def change
    add_column :assistant_tool_executions, :provider_name, :string
    add_column :assistant_tool_executions, :provider_tool_call_id, :string

    add_index :assistant_tool_executions, :provider_name
    add_index :assistant_tool_executions, :provider_tool_call_id
  end
end
