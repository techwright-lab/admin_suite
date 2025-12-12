# frozen_string_literal: true

class DropOldAiTables < ActiveRecord::Migration[8.1]
  def change
    # Drop old tables
    drop_table :ai_extraction_logs, if_exists: true do |t|
      t.references :scraping_attempt, null: true, foreign_key: true
      t.references :job_listing, null: true, foreign_key: true
      t.string :provider, null: false
      t.string :model, null: false
      t.integer :prompt_template_id
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :total_tokens
      t.integer :estimated_cost_cents
      t.integer :latency_ms
      t.float :confidence_score
      t.integer :status, null: false, default: 0
      t.string :error_type
      t.text :error_message
      t.jsonb :request_payload, default: {}
      t.jsonb :response_payload, default: {}
      t.integer :html_content_size
      t.jsonb :extracted_fields, default: []
      t.timestamps
    end

    drop_table :extraction_prompt_templates, if_exists: true do |t|
      t.string :name, null: false
      t.text :description
      t.text :prompt_template, null: false
      t.boolean :active, default: false, null: false
      t.integer :version, default: 1, null: false
      t.timestamps
    end
  end
end
