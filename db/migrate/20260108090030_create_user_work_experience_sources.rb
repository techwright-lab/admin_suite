# frozen_string_literal: true

class CreateUserWorkExperienceSources < ActiveRecord::Migration[8.1]
  def change
    create_table :user_work_experience_sources do |t|
      t.references :user_work_experience, null: false, foreign_key: true, index: { name: "idx_uwes_on_uwe_id" }
      t.references :resume_work_experience, null: false, foreign_key: true, index: { name: "idx_uwes_on_rwe_id" }

      t.timestamps
    end

    add_index :user_work_experience_sources,
              [ :user_work_experience_id, :resume_work_experience_id ],
              unique: true,
              name: "idx_uwes_unique"
  end
end
