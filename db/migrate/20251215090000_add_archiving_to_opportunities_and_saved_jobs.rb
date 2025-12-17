# frozen_string_literal: true

class AddArchivingToOpportunitiesAndSavedJobs < ActiveRecord::Migration[8.1]
  def change
    change_table :opportunities, bulk: true do |t|
      t.datetime :archived_at
      t.string :archived_reason
    end

    change_table :saved_jobs, bulk: true do |t|
      t.string :status, null: false, default: "active"
      t.datetime :archived_at
      t.string :archived_reason
    end

    add_index :saved_jobs, :status
    add_index :saved_jobs, :archived_at
  end
end



