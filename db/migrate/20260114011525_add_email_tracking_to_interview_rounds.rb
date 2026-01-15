class AddEmailTrackingToInterviewRounds < ActiveRecord::Migration[8.1]
  def change
    add_column :interview_rounds, :source_email_id, :bigint
    add_column :interview_rounds, :video_link, :string
    add_column :interview_rounds, :confirmation_source, :string
    add_index :interview_rounds, :source_email_id
  end
end
