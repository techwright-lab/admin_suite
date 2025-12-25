class CreateAssistantTurns < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_turns do |t|
      t.references :thread, null: false, foreign_key: { to_table: :assistant_threads }
      t.references :user_message, null: false, foreign_key: { to_table: :assistant_messages }
      t.references :assistant_message, null: false, foreign_key: { to_table: :assistant_messages }
      t.string :trace_id, null: false
      t.jsonb :context_snapshot, null: false, default: {}
      t.string :status, null: false, default: "success"
      t.references :llm_api_log, null: false, foreign_key: { to_table: :llm_api_logs }
      t.integer :latency_ms

      t.timestamps
    end

    add_index :assistant_turns, :trace_id
  end
end
