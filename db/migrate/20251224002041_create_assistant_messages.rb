class CreateAssistantMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_messages do |t|
      t.references :thread, null: false, foreign_key: { to_table: :assistant_threads }
      t.string :role, null: false
      t.text :content, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :assistant_messages, [ :thread_id, :created_at ]
  end
end
