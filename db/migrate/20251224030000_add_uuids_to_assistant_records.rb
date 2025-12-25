# frozen_string_literal: true

require "securerandom"

class AddUuidsToAssistantRecords < ActiveRecord::Migration[8.1]
  def up
    add_column :assistant_threads, :uuid, :uuid
    add_column :assistant_messages, :uuid, :uuid
    add_column :assistant_turns, :uuid, :uuid
    add_column :assistant_tool_executions, :uuid, :uuid
    add_column :assistant_events, :uuid, :uuid
    add_column :assistant_memory_proposals, :uuid, :uuid
    add_column :assistant_thread_summaries, :uuid, :uuid
    add_column :assistant_user_memories, :uuid, :uuid

    backfill_uuid(:assistant_threads)
    backfill_uuid(:assistant_messages)
    backfill_uuid(:assistant_turns)
    backfill_uuid(:assistant_tool_executions)
    backfill_uuid(:assistant_events)
    backfill_uuid(:assistant_memory_proposals)
    backfill_uuid(:assistant_thread_summaries)
    backfill_uuid(:assistant_user_memories)

    change_column_null :assistant_threads, :uuid, false
    change_column_null :assistant_messages, :uuid, false
    change_column_null :assistant_turns, :uuid, false
    change_column_null :assistant_tool_executions, :uuid, false
    change_column_null :assistant_events, :uuid, false
    change_column_null :assistant_memory_proposals, :uuid, false
    change_column_null :assistant_thread_summaries, :uuid, false
    change_column_null :assistant_user_memories, :uuid, false

    add_index :assistant_threads, :uuid, unique: true
    add_index :assistant_messages, :uuid, unique: true
    add_index :assistant_turns, :uuid, unique: true
    add_index :assistant_tool_executions, :uuid, unique: true
    add_index :assistant_events, :uuid, unique: true
    add_index :assistant_memory_proposals, :uuid, unique: true
    add_index :assistant_thread_summaries, :uuid, unique: true
    add_index :assistant_user_memories, :uuid, unique: true
  end

  def down
    remove_index :assistant_user_memories, :uuid
    remove_index :assistant_thread_summaries, :uuid
    remove_index :assistant_memory_proposals, :uuid
    remove_index :assistant_events, :uuid
    remove_index :assistant_tool_executions, :uuid
    remove_index :assistant_turns, :uuid
    remove_index :assistant_messages, :uuid
    remove_index :assistant_threads, :uuid

    remove_column :assistant_user_memories, :uuid
    remove_column :assistant_thread_summaries, :uuid
    remove_column :assistant_memory_proposals, :uuid
    remove_column :assistant_events, :uuid
    remove_column :assistant_tool_executions, :uuid
    remove_column :assistant_turns, :uuid
    remove_column :assistant_messages, :uuid
    remove_column :assistant_threads, :uuid
  end

  private

  def backfill_uuid(table)
    ids = select_values("SELECT id FROM #{table} WHERE uuid IS NULL")
    ids.each do |id|
      execute <<~SQL.squish
        UPDATE #{table}
        SET uuid = '#{SecureRandom.uuid}'
        WHERE id = #{id.to_i} AND uuid IS NULL
      SQL
    end
  end
end
