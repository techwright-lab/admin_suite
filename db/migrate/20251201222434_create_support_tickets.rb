class CreateSupportTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :support_tickets do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :subject, null: false
      t.text :message, null: false
      t.string :status, null: false, default: "open"
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :support_tickets, :status
    add_index :support_tickets, :email
    add_index :support_tickets, :created_at
  end
end
