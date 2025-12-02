class AddUuidToInterviewApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :interview_applications, :uuid, :string
    add_column :interview_applications, :slug, :string

    add_index :interview_applications, :uuid, unique: true
    add_index :interview_applications, :slug, unique: true
  end
end
