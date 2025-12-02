class AddDefaultsToInterviewApplications < ActiveRecord::Migration[8.1]
  def up
    change_column_default :interview_applications, :status, from: nil, to: 0
    change_column_default :interview_applications, :pipeline_stage, from: nil, to: 0
    change_column_default :interview_applications, :applied_at, from: nil, to: -> { 'CURRENT_DATE' }

    # Update existing records with nil values
    execute <<-SQL
      UPDATE interview_applications#{' '}
      SET status = 0#{' '}
      WHERE status IS NULL;
    SQL

    execute <<-SQL
      UPDATE interview_applications#{' '}
      SET pipeline_stage = 0#{' '}
      WHERE pipeline_stage IS NULL;
    SQL

    execute <<-SQL
      UPDATE interview_applications#{' '}
      SET applied_at = CURRENT_DATE#{' '}
      WHERE applied_at IS NULL;
    SQL
  end

  def down
    change_column_default :interview_applications, :status, from: 0, to: nil
    change_column_default :interview_applications, :pipeline_stage, from: 0, to: nil
    change_column_default :interview_applications, :applied_at, from: -> { 'CURRENT_DATE' }, to: nil
  end
end
