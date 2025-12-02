class CleanupInterviewApplicationsColumns < ActiveRecord::Migration[8.1]
  def up
    # Delete related records first (interview_skill_tags)
    execute <<-SQL
      DELETE FROM interview_skill_tags 
      WHERE interview_id IN (
        SELECT id FROM interview_applications WHERE company_id IS NULL OR job_role_id IS NULL
      );
    SQL
    
    # Delete any records without company_id or job_role_id (old seed data)
    execute <<-SQL
      DELETE FROM interview_applications WHERE company_id IS NULL OR job_role_id IS NULL;
    SQL
    
    # Remove old string columns that have been replaced with foreign keys
    remove_column :interview_applications, :company, :string if column_exists?(:interview_applications, :company)
    remove_column :interview_applications, :role, :string if column_exists?(:interview_applications, :role)
    
    # Remove old stage column (replaced by status and pipeline_stage)
    remove_column :interview_applications, :stage, :integer if column_exists?(:interview_applications, :stage)
    
    # Remove old date column (replaced by applied_at)
    remove_column :interview_applications, :date, :date if column_exists?(:interview_applications, :date)
    
    # Make foreign keys NOT NULL
    change_column_null :interview_applications, :company_id, false
    change_column_null :interview_applications, :job_role_id, false
  end

  def down
    # Add back old columns
    add_column :interview_applications, :company, :string
    add_column :interview_applications, :role, :string
    add_column :interview_applications, :stage, :integer, default: 0
    add_column :interview_applications, :date, :date
    
    # Make foreign keys nullable again
    change_column_null :interview_applications, :company_id, true
    change_column_null :interview_applications, :job_role_id, true
  end
end
