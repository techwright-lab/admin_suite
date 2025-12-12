# frozen_string_literal: true

class CreateLlmApiLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_api_logs do |t|
      # Operation type to categorize the LLM call
      t.string :operation_type, null: false # job_extraction, email_extraction, resume_extraction, etc.

      # Polymorphic association to the object being processed
      t.references :loggable, polymorphic: true, null: true

      # Reference to the prompt used (if any)
      t.references :llm_prompt, null: true, foreign_key: true

      # Provider info
      t.string :provider, null: false # openai, anthropic, ollama
      t.string :model, null: false # model identifier (gpt-4o, claude-sonnet-4-20250514, etc.)

      # Token usage
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :total_tokens

      # Cost tracking (in cents for precision)
      t.integer :estimated_cost_cents

      # Performance
      t.integer :latency_ms
      t.float :confidence_score

      # Status tracking (enum)
      t.integer :status, null: false, default: 0 # success, error, timeout, rate_limited

      # Error details
      t.string :error_type
      t.text :error_message

      # Full request/response payloads for debugging
      t.jsonb :request_payload, default: {}
      t.jsonb :response_payload, default: {}

      # Content info
      t.integer :content_size # bytes of content processed (HTML, text, etc.)
      t.jsonb :extracted_fields, default: [] # which fields were extracted

      t.timestamps
    end

    # Indexes for common queries
    add_index :llm_api_logs, :operation_type
    add_index :llm_api_logs, :provider
    add_index :llm_api_logs, :status
    add_index :llm_api_logs, :created_at
    add_index :llm_api_logs, [ :provider, :status ]
    add_index :llm_api_logs, [ :provider, :created_at ]
    add_index :llm_api_logs, [ :operation_type, :status ]
    add_index :llm_api_logs, [ :operation_type, :created_at ]
    add_index :llm_api_logs, [ :loggable_type, :loggable_id ]
  end
end
