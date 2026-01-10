# frozen_string_literal: true

class CreateResumeWorkExperienceSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :resume_work_experience_skills do |t|
      t.references :resume_work_experience, null: false, foreign_key: true, index: { name: "idx_rwes_on_rwe_id" }
      t.references :skill_tag, null: false, foreign_key: true

      # Optional evidence/confidence per experience-skill
      t.float :confidence_score
      t.text :evidence_snippet

      t.timestamps
    end

    add_index :resume_work_experience_skills,
              [ :resume_work_experience_id, :skill_tag_id ],
              unique: true,
              name: "idx_rwes_unique"
  end
end
