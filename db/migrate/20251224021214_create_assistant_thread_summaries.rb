class CreateAssistantThreadSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_thread_summaries do |t|
      t.references :thread, null: false, foreign_key: { to_table: :assistant_threads }, index: { unique: true }
      t.text :summary_text, null: false, default: ""
      t.integer :summary_version, null: false, default: 1
      t.references :last_summarized_message, null: true, foreign_key: { to_table: :assistant_messages }
      t.references :llm_api_log, null: true, foreign_key: { to_table: :llm_api_logs }

      t.timestamps
    end
  end
end
