class UpdateInterviewApplicationStateDefaults < ActiveRecord::Migration[8.1]
  def change
    remove_column :interview_applications, :status, :string
    remove_column :interview_applications, :pipeline_stage, :string
    add_column :interview_applications, :status, :string
    add_column :interview_applications, :pipeline_stage, :string

    add_index :interview_applications, :status
    add_index :interview_applications, :pipeline_stage
  end
end
