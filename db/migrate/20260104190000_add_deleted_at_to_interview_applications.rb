# frozen_string_literal: true

class AddDeletedAtToInterviewApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :interview_applications, :deleted_at, :datetime
    add_index :interview_applications, :deleted_at
    add_index :interview_applications, [ :user_id, :deleted_at ]
  end
end
