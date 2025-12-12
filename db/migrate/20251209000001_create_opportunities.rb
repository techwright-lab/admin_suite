# frozen_string_literal: true

# Migration to create opportunities table for tracking recruiter outreach emails
class CreateOpportunities < ActiveRecord::Migration[8.1]
  def change
    create_table :opportunities do |t|
      # Core associations
      t.references :user, null: false, foreign_key: true
      t.references :synced_email, null: true, foreign_key: true
      t.references :interview_application, null: true, foreign_key: true

      # Status tracking (string for AASM compatibility)
      t.string :status, null: false, default: "new"
      t.string :source_type

      # Extracted job information
      t.string :company_name
      t.string :job_role_title
      t.string :job_url

      # Recruiter information
      t.string :recruiter_name
      t.string :recruiter_email
      t.string :recruiter_company

      # AI extraction data
      t.jsonb :extracted_links, default: []
      t.jsonb :extracted_data, default: {}
      t.float :ai_confidence_score

      # Additional context
      t.text :key_details
      t.text :email_snippet

      t.timestamps
    end

    # Indexes for common queries
    add_index :opportunities, :status
    add_index :opportunities, :source_type
    add_index :opportunities, [ :user_id, :status ]
    add_index :opportunities, [ :user_id, :created_at ]
  end
end
