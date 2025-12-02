class CreateSyncedEmails < ActiveRecord::Migration[8.1]
  def change
    create_table :synced_emails do |t|
      t.references :user, null: false, foreign_key: true
      t.references :connected_account, null: false, foreign_key: true
      t.references :interview_application, foreign_key: true # Optional - may not be matched yet
      t.references :email_sender, foreign_key: true # Link to sender record
      t.string :gmail_id, null: false
      t.string :thread_id
      t.string :subject
      t.string :from_email, null: false
      t.string :from_name
      t.datetime :email_date
      t.text :snippet
      t.text :body_preview
      t.integer :status, default: 0, null: false # pending, processed, ignored, failed
      t.string :email_type # invite, confirmation, rejection, offer, follow_up, other
      t.string :detected_company
      t.jsonb :labels, default: [] # Gmail labels
      t.jsonb :metadata, default: {} # Additional parsed data

      t.timestamps
    end

    add_index :synced_emails, [:user_id, :gmail_id], unique: true
    add_index :synced_emails, :thread_id
    add_index :synced_emails, :email_date
    add_index :synced_emails, :status
    add_index :synced_emails, :email_type
    add_index :synced_emails, :from_email
  end
end
