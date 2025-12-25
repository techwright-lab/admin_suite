class CreateAssistantUserMemories < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_user_memories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :key, null: false
      t.jsonb :value, null: false, default: {}
      t.float :confidence, null: false, default: 1.0
      t.string :source, null: false, default: "user"
      t.datetime :expires_at
      t.datetime :last_confirmed_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :assistant_user_memories, [ :user_id, :key ], unique: true
    add_index :assistant_user_memories, :expires_at
  end
end
