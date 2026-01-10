# frozen_string_literal: true

class CreateResumeWorkExperiences < ActiveRecord::Migration[8.1]
  def change
    create_table :resume_work_experiences do |t|
      t.references :user_resume, null: false, foreign_key: true

      # Best-effort links to canonical entities
      t.references :company, null: true, foreign_key: true
      t.references :job_role, null: true, foreign_key: true

      # Denormalized text (from resume) for robustness even if linking fails
      t.string :company_name
      t.string :role_title

      # Expanded experience fields
      t.date :start_date
      t.date :end_date
      t.boolean :current, null: false, default: false

      # Legacy/loose duration string if dates are not available
      t.string :duration_text

      # Rich content
      t.jsonb :responsibilities, null: false, default: []
      t.jsonb :highlights, null: false, default: []

      # Optional additional extracted fields (location, team size, etc.)
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :resume_work_experiences, [ :user_resume_id, :start_date, :end_date ], name: "idx_resume_work_experiences_by_dates"
    add_index :resume_work_experiences, [ :company_name, :role_title ], name: "idx_resume_work_experiences_company_role"
  end
end
