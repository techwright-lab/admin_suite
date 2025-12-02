class RenameInterviewsToApplications < ActiveRecord::Migration[8.1]
  def change
    # Rename the table
    rename_table :interviews, :interview_applications

    # Add new columns for job_listing, company, and job_role
    add_reference :interview_applications, :job_listing, foreign_key: true, index: true
    add_reference :interview_applications, :company, foreign_key: true, index: true
    add_reference :interview_applications, :job_role, foreign_key: true, index: true

    # Rename and update status column (was stage, now status)
    rename_column :interview_applications, :stage, :status unless column_exists?(:interview_applications, :status)

    # Add applied_at column
    add_column :interview_applications, :applied_at, :datetime unless column_exists?(:interview_applications, :applied_at)

    # Update indexes
    remove_index :interview_applications, :status if index_exists?(:interview_applications, :status)
    add_index :interview_applications, :status unless index_exists?(:interview_applications, :status)
  end
end
