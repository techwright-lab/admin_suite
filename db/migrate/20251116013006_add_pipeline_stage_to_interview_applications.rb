class AddPipelineStageToInterviewApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :interview_applications, :pipeline_stage, :integer, default: 0, null: false
    add_index :interview_applications, :pipeline_stage
  end
end
