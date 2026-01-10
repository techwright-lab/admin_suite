# frozen_string_literal: true

class CreateUserWorkExperienceSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :user_work_experience_skills do |t|
      t.references :user_work_experience, null: false, foreign_key: true, index: { name: "idx_uwesk_on_uwe_id" }
      t.references :skill_tag, null: false, foreign_key: true

      # Aggregates across all sources (resume experiences)
      t.integer :source_count, null: false, default: 0
      t.date :last_used_on

      t.timestamps
    end

    add_index :user_work_experience_skills,
              [ :user_work_experience_id, :skill_tag_id ],
              unique: true,
              name: "idx_uwesk_unique"
  end
end
