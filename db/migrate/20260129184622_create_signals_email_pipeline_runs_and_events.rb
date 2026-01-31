class CreateSignalsEmailPipelineRunsAndEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :email_pipeline_runs do |t|
      t.references :synced_email, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :connected_account, null: false, foreign_key: true

      t.integer :status, null: false, default: 0
      t.string :trigger, null: false, default: "gmail_sync"
      t.string :mode, null: false, default: "unknown"

      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.integer :duration_ms

      t.string :error_type
      t.text :error_message
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :email_pipeline_runs, :created_at
    add_index :email_pipeline_runs, :status

    create_table :email_pipeline_events do |t|
      t.references :run, null: false, foreign_key: { to_table: :email_pipeline_runs }
      t.references :synced_email, null: false, foreign_key: true
      t.references :interview_application, foreign_key: true

      t.integer :step_order, null: false
      t.string :event_type, null: false
      t.integer :status, null: false, default: 0

      t.datetime :started_at
      t.datetime :completed_at
      t.integer :duration_ms

      t.jsonb :input_payload, null: false, default: {}
      t.jsonb :output_payload, null: false, default: {}
      t.string :error_type
      t.text :error_message
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :email_pipeline_events, [ :run_id, :step_order ], unique: true
    add_index :email_pipeline_events, :created_at
    add_index :email_pipeline_events, :event_type
    add_index :email_pipeline_events, :status
  end
end
