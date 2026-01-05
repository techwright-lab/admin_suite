# frozen_string_literal: true

class AddJobDescriptionTextToInterviewApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :interview_applications, :job_description_text, :text
  end
end
