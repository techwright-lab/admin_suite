class CreateInterviewRounds < ActiveRecord::Migration[8.1]
  def change
    create_table :interview_rounds do |t|
      t.references :interview_application, null: false, foreign_key: true
      t.integer :stage, null: false, default: 0
      t.string :stage_name
      t.datetime :scheduled_at
      t.datetime :completed_at
      t.integer :duration_minutes
      t.string :interviewer_name
      t.string :interviewer_role
      t.text :notes
      t.integer :result, default: 0
      t.integer :position

      t.timestamps
    end

    add_index :interview_rounds, :stage
    add_index :interview_rounds, :result
    add_index :interview_rounds, [ :interview_application_id, :position ]
  end
end
