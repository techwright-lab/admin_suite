# frozen_string_literal: true

class AddResumeDateToUserResumes < ActiveRecord::Migration[8.0]
  def change
    add_column :user_resumes, :resume_updated_at, :date
    add_column :user_resumes, :resume_date_confidence, :string
    add_column :user_resumes, :resume_date_source, :string
  end
end

