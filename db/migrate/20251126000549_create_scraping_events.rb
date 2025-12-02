class CreateScrapingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :scraping_events do |t|
      # Associations
      t.references :scraping_attempt, null: false, foreign_key: true
      t.references :job_listing, null: true, foreign_key: true

      # Event identification
      t.string :event_type, null: false # permission_check, html_fetch, nokogiri_scrape, api_extraction, ai_extraction, completion, failure
      t.integer :step_order # Order in pipeline (1, 2, 3...)
      t.integer :status, null: false, default: 0 # enum: started, success, failed, skipped

      # Timing
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :duration_ms

      # Payloads for debugging
      t.jsonb :input_payload, default: {}
      t.jsonb :output_payload, default: {}

      # Error handling
      t.string :error_type
      t.text :error_message

      # Additional context
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    # Indexes for common queries
    add_index :scraping_events, :event_type
    add_index :scraping_events, :status
    add_index :scraping_events, :created_at
    add_index :scraping_events, [ :scraping_attempt_id, :step_order ]
    add_index :scraping_events, [ :scraping_attempt_id, :event_type ]
  end
end
