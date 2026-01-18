# frozen_string_literal: true

# Creates the interview_round_prep_artifacts table for storing AI-generated
# interview preparation content for specific interview rounds.
class CreateInterviewRoundPrepArtifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :interview_round_prep_artifacts do |t|
      t.references :interview_round, null: false, foreign_key: true
      t.string :kind, null: false
      t.jsonb :content, default: {}
      t.string :inputs_digest
      t.integer :status, default: 0, null: false
      t.datetime :generated_at

      t.timestamps
    end

    # Unique constraint: one artifact per round per kind
    add_index :interview_round_prep_artifacts, [ :interview_round_id, :kind ], unique: true, name: "idx_round_prep_artifacts_unique"
    # For cache invalidation lookups
    add_index :interview_round_prep_artifacts, :inputs_digest
  end
end
