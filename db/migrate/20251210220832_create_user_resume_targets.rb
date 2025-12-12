# frozen_string_literal: true

class CreateUserResumeTargets < ActiveRecord::Migration[8.1]
  def change
    # Create join table for resume -> job roles (many-to-many)
    create_table :user_resume_target_job_roles do |t|
      t.references :user_resume, null: false, foreign_key: true
      t.references :job_role, null: false, foreign_key: true
      t.timestamps
    end

    add_index :user_resume_target_job_roles,
              [ :user_resume_id, :job_role_id ],
              unique: true,
              name: "idx_resume_target_roles_unique"

    # Create join table for resume -> companies (many-to-many)
    create_table :user_resume_target_companies do |t|
      t.references :user_resume, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.timestamps
    end

    add_index :user_resume_target_companies,
              [ :user_resume_id, :company_id ],
              unique: true,
              name: "idx_resume_target_companies_unique"

    # Remove the old single-target columns from user_resumes
    remove_reference :user_resumes, :target_job_role, foreign_key: { to_table: :job_roles }
    remove_reference :user_resumes, :target_company, foreign_key: { to_table: :companies }
  end
end
