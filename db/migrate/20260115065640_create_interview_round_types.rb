# frozen_string_literal: true

# Creates the interview_round_types table for database-driven round type classification.
# Round types are associated with departments (Categories) - nil category means universal.
class CreateInterviewRoundTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :interview_round_types do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.references :category, null: true, foreign_key: true
      t.integer :position, default: 0, null: false
      t.datetime :disabled_at

      t.timestamps
    end

    add_index :interview_round_types, :slug, unique: true
    add_index :interview_round_types, [ :category_id, :position ]
  end
end
