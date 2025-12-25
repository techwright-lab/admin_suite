class CreateAssistantThreads < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_threads do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.string :status, null: false, default: "open"
      t.datetime :last_activity_at

      t.timestamps
    end

    add_index :assistant_threads, [ :user_id, :last_activity_at ]
  end
end
