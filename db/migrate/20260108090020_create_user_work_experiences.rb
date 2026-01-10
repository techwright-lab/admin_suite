# frozen_string_literal: true

class CreateUserWorkExperiences < ActiveRecord::Migration[8.1]
  def change
    create_table :user_work_experiences do |t|
      t.references :user, null: false, foreign_key: true

      t.references :company, null: true, foreign_key: true
      t.references :job_role, null: true, foreign_key: true

      # Canonical-ish display values (merged across resumes)
      t.string :company_name
      t.string :role_title

      # Merged date range (best-effort)
      t.date :start_date
      t.date :end_date
      t.boolean :current, null: false, default: false

      # Merged summaries (best-effort)
      t.jsonb :highlights, null: false, default: []
      t.jsonb :responsibilities, null: false, default: []

      # Provenance and merge bookkeeping
      t.integer :source_count, null: false, default: 0
      t.jsonb :merge_keys, null: false, default: {}

      t.timestamps
    end

    add_index :user_work_experiences, [ :user_id, :company_name, :role_title ], name: "idx_user_work_experiences_user_company_role"
    add_index :user_work_experiences, [ :user_id, :start_date, :end_date ], name: "idx_user_work_experiences_user_dates"
  end
end
