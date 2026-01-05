# frozen_string_literal: true

class CreateInterviewPrepArtifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :interview_prep_artifacts do |t|
      t.string :uuid, null: false

      t.references :interview_application, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :llm_api_log, null: true, foreign_key: { to_table: :llm_api_logs }

      t.integer :kind, null: false
      t.integer :status, null: false, default: 0

      t.string :inputs_digest, null: false
      t.jsonb :content, null: false, default: {}
      t.datetime :computed_at
      t.string :error_message

      t.string :provider
      t.string :model

      t.timestamps
    end

    add_index :interview_prep_artifacts, :uuid, unique: true
    add_index :interview_prep_artifacts, [ :interview_application_id, :kind ], unique: true, name: "idx_prep_artifacts_on_app_and_kind"
    add_index :interview_prep_artifacts, [ :user_id, :kind ], name: "idx_prep_artifacts_on_user_and_kind"
    add_index :interview_prep_artifacts, :status
    add_index :interview_prep_artifacts, :inputs_digest
  end
end
