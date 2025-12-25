class CreateAssistantToolExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_tool_executions do |t|
      t.references :thread, null: false, foreign_key: { to_table: :assistant_threads }
      t.references :assistant_message, null: false, foreign_key: { to_table: :assistant_messages }
      t.string :tool_key, null: false
      t.jsonb :args, null: false, default: {}
      t.jsonb :result, null: false, default: {}
      t.string :status, null: false, default: "proposed"
      t.string :trace_id, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error
      t.boolean :requires_confirmation, null: false, default: false
      t.datetime :approved_at
      t.references :approved_by, null: true, foreign_key: { to_table: :users }
      t.string :idempotency_key

      t.timestamps
    end

    add_index :assistant_tool_executions, :trace_id
    add_index :assistant_tool_executions, [ :thread_id, :idempotency_key ], unique: true
  end
end
