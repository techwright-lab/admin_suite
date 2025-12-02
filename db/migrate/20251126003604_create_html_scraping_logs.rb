class CreateHtmlScrapingLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :html_scraping_logs do |t|
      # Associations
      t.references :scraping_attempt, null: false, foreign_key: true
      t.references :job_listing, null: true, foreign_key: true

      # Source info
      t.string :url, null: false
      t.string :domain, null: false
      t.integer :html_size # bytes of HTML processed
      t.integer :cleaned_html_size # bytes of cleaned HTML

      # Timing
      t.integer :duration_ms
      t.integer :status, null: false, default: 0 # enum: success, partial, failed

      # Field-level extraction results
      t.jsonb :field_results, default: {} # { field_name: { success: bool, value: string, selector_matched: string, confidence: float } }
      t.jsonb :selectors_tried, default: {} # { field_name: [selectors tried] }

      # Summary metrics
      t.integer :fields_attempted, default: 0
      t.integer :fields_extracted, default: 0
      t.float :extraction_rate # fields_extracted / fields_attempted

      # Error tracking
      t.string :error_type
      t.text :error_message

      t.timestamps
    end

    # Indexes for analytics queries
    add_index :html_scraping_logs, :domain
    add_index :html_scraping_logs, :status
    add_index :html_scraping_logs, :extraction_rate
    add_index :html_scraping_logs, :created_at
    add_index :html_scraping_logs, [ :domain, :created_at ]
    add_index :html_scraping_logs, [ :domain, :status ]
  end
end
