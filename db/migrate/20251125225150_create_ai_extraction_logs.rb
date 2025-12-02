class CreateAiExtractionLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_extraction_logs do |t|
      # Associations
      t.references :scraping_attempt, null: true, foreign_key: true
      t.references :job_listing, null: true, foreign_key: true

      # Provider info
      t.string :provider, null: false # openai, anthropic, ollama
      t.string :model, null: false # model identifier

      # Prompt template tracking (optional)
      t.integer :prompt_template_id

      # Token usage
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :total_tokens

      # Cost tracking (in cents for precision)
      t.integer :estimated_cost_cents

      # Performance
      t.integer :latency_ms
      t.float :confidence_score

      # Status tracking
      t.integer :status, null: false, default: 0 # enum: success, error, timeout, rate_limited

      # Error details
      t.string :error_type
      t.text :error_message

      # Full request/response payloads for debugging
      t.jsonb :request_payload, default: {}
      t.jsonb :response_payload, default: {}

      # Content info
      t.integer :html_content_size # bytes of HTML processed
      t.jsonb :extracted_fields, default: [] # which fields were extracted

      t.timestamps
    end

    # Indexes for common queries
    add_index :ai_extraction_logs, :provider
    add_index :ai_extraction_logs, :status
    add_index :ai_extraction_logs, :created_at
    add_index :ai_extraction_logs, [ :provider, :status ]
    add_index :ai_extraction_logs, [ :provider, :created_at ]
    add_index :ai_extraction_logs, :prompt_template_id
  end
end
