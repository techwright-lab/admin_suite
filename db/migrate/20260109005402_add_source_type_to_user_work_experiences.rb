# frozen_string_literal: true

class AddSourceTypeToUserWorkExperiences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_work_experiences, :source_type, :integer, default: 0, null: false
    add_index :user_work_experiences, :source_type
  end
end
