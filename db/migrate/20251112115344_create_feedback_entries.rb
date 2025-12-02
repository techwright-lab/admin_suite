class CreateFeedbackEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :feedback_entries do |t|
      t.references :interview, null: false, foreign_key: true
      t.text :went_well
      t.text :to_improve
      t.text :interviewer_notes
      t.text :self_reflection
      t.text :ai_summary
      t.text :tags
      t.string :recommended_action

      t.timestamps
    end
  end
end
