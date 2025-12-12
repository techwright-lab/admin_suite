# frozen_string_literal: true

class CreateResumeSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :resume_skills do |t|
      t.references :user_resume, null: false, foreign_key: true
      t.references :skill_tag, null: false, foreign_key: true
      t.integer :model_level, null: false
      t.integer :user_level
      t.float :confidence_score
      t.string :category
      t.text :evidence_snippet
      t.integer :years_of_experience

      t.timestamps
    end

    add_index :resume_skills, [ :user_resume_id, :skill_tag_id ], unique: true
    add_index :resume_skills, :category
  end
end
