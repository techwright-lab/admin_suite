class RenameF < ActiveRecord::Migration[8.1]
  def change
    rename_table :feedback_entries, :interview_feedbacks unless table_exists?(:interview_feedbacks)
  end
end
