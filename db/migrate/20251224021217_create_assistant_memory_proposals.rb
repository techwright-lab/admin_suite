class CreateAssistantMemoryProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_memory_proposals do |t|
      t.references :thread, null: false, foreign_key: { to_table: :assistant_threads }
      t.references :user, null: false, foreign_key: true
      t.string :trace_id, null: false
      t.jsonb :proposed_items, null: false, default: []
      t.string :status, null: false, default: "pending"
      t.references :llm_api_log, null: true, foreign_key: { to_table: :llm_api_logs }
      t.datetime :confirmed_at
      t.references :confirmed_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :assistant_memory_proposals, :trace_id
    add_index :assistant_memory_proposals, [ :user_id, :status ]
  end
end
