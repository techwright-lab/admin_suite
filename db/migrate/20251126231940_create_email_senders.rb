class CreateEmailSenders < ActiveRecord::Migration[8.1]
  def change
    create_table :email_senders do |t|
      t.string :email, null: false
      t.string :name
      t.string :domain, null: false
      t.references :company, foreign_key: true # Admin-assigned company
      t.references :auto_detected_company, foreign_key: { to_table: :companies } # Auto-detected
      t.integer :email_count, default: 1, null: false
      t.datetime :last_seen_at
      t.boolean :verified, default: false # Admin verified the company association
      t.string :sender_type # recruiter, hiring_manager, hr, ats_system, unknown

      t.timestamps
    end

    add_index :email_senders, :email, unique: true
    add_index :email_senders, :domain
    add_index :email_senders, :verified
  end
end
