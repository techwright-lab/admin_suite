# frozen_string_literal: true

class AddReplayIdempotencyToAssistantToolExecutions < ActiveRecord::Migration[8.1]
  def change
    add_column :assistant_tool_executions, :replay_of_id, :bigint
    add_column :assistant_tool_executions, :replay_request_uuid, :uuid

    add_index :assistant_tool_executions, :replay_of_id
    add_index :assistant_tool_executions,
      %i[replay_of_id replay_request_uuid],
      unique: true,
      where: "replay_of_id IS NOT NULL AND replay_request_uuid IS NOT NULL",
      name: "idx_assistant_tool_executions_replay_idempotency"
  end
end
