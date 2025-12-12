# frozen_string_literal: true

class CreateUserSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :user_skills do |t|
      t.references :user, null: false, foreign_key: true
      t.references :skill_tag, null: false, foreign_key: true
      t.float :aggregated_level, null: false
      t.float :confidence_score
      t.string :category
      t.integer :resume_count, default: 0
      t.integer :max_years_experience
      t.datetime :last_demonstrated_at

      t.timestamps
    end

    add_index :user_skills, [ :user_id, :skill_tag_id ], unique: true
    add_index :user_skills, [ :user_id, :category ]
    add_index :user_skills, [ :user_id, :aggregated_level ]
  end
end
