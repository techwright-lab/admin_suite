# frozen_string_literal: true

# Adds signal extraction fields to synced_emails for AI-extracted intelligence
#
# These fields store extracted company, recruiter, and job information
# along with suggested actions derived from email content.
class AddSignalExtractionToSyncedEmails < ActiveRecord::Migration[8.0]
  def change
    add_column :synced_emails, :extracted_data, :jsonb, default: {}, null: false
    add_column :synced_emails, :extraction_status, :string, default: "pending"
    add_column :synced_emails, :extraction_confidence, :decimal, precision: 3, scale: 2
    add_column :synced_emails, :extracted_at, :datetime

    add_index :synced_emails, :extraction_status
  end
end
