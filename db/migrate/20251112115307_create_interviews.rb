class CreateInterviews < ActiveRecord::Migration[8.1]
  def change
    create_table :interviews do |t|
      t.references :user, null: false, foreign_key: true
      t.string :company, null: false
      t.string :role, null: false
      t.integer :stage, null: false, default: 0
      t.string :status
      t.date :date
      t.text :notes
      t.text :ai_summary

      t.timestamps
    end

    add_index :interviews, [ :user_id, :created_at ]
    add_index :interviews, :stage
  end
end
