# frozen_string_literal: true

class CreateUserResumes < ActiveRecord::Migration[8.1]
  def change
    create_table :user_resumes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.references :target_job_role, foreign_key: { to_table: :job_roles }
      t.references :target_company, foreign_key: { to_table: :companies }
      t.integer :purpose, default: 0, null: false
      t.integer :analysis_status, default: 0, null: false
      t.datetime :analyzed_at
      t.text :analysis_summary
      t.text :parsed_text
      t.jsonb :extracted_data, default: {}

      t.timestamps
    end

    add_index :user_resumes, [ :user_id, :created_at ]
    add_index :user_resumes, :analysis_status
  end
end
