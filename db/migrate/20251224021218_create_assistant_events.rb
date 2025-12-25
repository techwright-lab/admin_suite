class CreateAssistantEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_events do |t|
      t.references :thread, null: false, foreign_key: { to_table: :assistant_threads }
      t.string :trace_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :severity, null: false, default: "info"

      t.timestamps
    end

    add_index :assistant_events, :trace_id
    add_index :assistant_events, [ :thread_id, :created_at ]
    add_index :assistant_events, [ :event_type, :created_at ]
  end
end
