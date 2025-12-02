class CreateScrapingAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :scraping_attempts do |t|
      t.references :job_listing, null: false, foreign_key: true
      t.string :url, null: false
      t.string :domain, null: false
      t.string :extraction_method # "api", "ai"
      t.string :provider # "greenhouse", "lever", "openai", "anthropic"
      t.integer :http_status
      t.float :confidence_score
      t.text :error_message
      t.jsonb :request_metadata, default: {}
      t.jsonb :response_metadata, default: {}
      t.integer :status, null: false, default: 0 # AASM enum
      t.float :duration_seconds
      t.integer :retry_count, default: 0

      t.timestamps
    end

    add_index :scraping_attempts, :domain
    add_index :scraping_attempts, :status
    add_index :scraping_attempts, [:domain, :status]
    add_index :scraping_attempts, [:status, :created_at]
    add_index :scraping_attempts, :created_at
  end
end
