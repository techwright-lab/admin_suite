class AddInterviewRoundIdToInterviewFeedbacks < ActiveRecord::Migration[8.1]
  def change
    # Rename the interview_id column to interview_round_id
    if column_exists?(:interview_feedbacks, :interview_id) && !column_exists?(:interview_feedbacks, :interview_round_id)
      rename_column :interview_feedbacks, :interview_id, :interview_round_id
    end
  end
end
