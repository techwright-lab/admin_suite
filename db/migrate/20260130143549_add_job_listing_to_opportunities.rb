class AddJobListingToOpportunities < ActiveRecord::Migration[8.1]
  def change
    add_reference :opportunities, :job_listing, null: true, foreign_key: true
  end
end
