# frozen_string_literal: true

class UpdateSavedJobsUniqueIndexesForArchiving < ActiveRecord::Migration[8.1]
  def change
    remove_index :saved_jobs, name: "index_saved_jobs_on_user_and_opportunity_unique"
    remove_index :saved_jobs, name: "index_saved_jobs_on_user_and_url_unique"

    add_index :saved_jobs,
      [ :user_id, :opportunity_id ],
      unique: true,
      where: "opportunity_id IS NOT NULL AND status = 'active'",
      name: "index_saved_jobs_on_user_and_opportunity_unique"

    add_index :saved_jobs,
      [ :user_id, :url ],
      unique: true,
      where: "url IS NOT NULL AND status = 'active'",
      name: "index_saved_jobs_on_user_and_url_unique"
  end
end



