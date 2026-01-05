# frozen_string_literal: true

class FixInterviewFeedbacksForeignKey < ActiveRecord::Migration[8.1]
  def up
    # Remove the incorrect foreign key constraint
    remove_foreign_key :interview_feedbacks, :interview_applications, column: :interview_round_id if foreign_key_exists?(:interview_feedbacks, :interview_applications, column: :interview_round_id)
    
    # Add the correct foreign key constraint
    add_foreign_key :interview_feedbacks, :interview_rounds, column: :interview_round_id unless foreign_key_exists?(:interview_feedbacks, :interview_rounds, column: :interview_round_id)
  end

  def down
    # Remove the correct foreign key
    remove_foreign_key :interview_feedbacks, :interview_rounds, column: :interview_round_id if foreign_key_exists?(:interview_feedbacks, :interview_rounds, column: :interview_round_id)
    
    # Restore the incorrect foreign key (for rollback purposes)
    add_foreign_key :interview_feedbacks, :interview_applications, column: :interview_round_id unless foreign_key_exists?(:interview_feedbacks, :interview_applications, column: :interview_round_id)
  end
end
