class CreateCompanyFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :company_feedbacks do |t|
      t.references :interview_application, null: false, foreign_key: true
      t.text :feedback_text
      t.datetime :received_at
      t.text :rejection_reason
      t.text :next_steps
      t.text :self_reflection

      t.timestamps
    end
  end
end
