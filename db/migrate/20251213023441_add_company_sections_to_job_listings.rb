class AddCompanySectionsToJobListings < ActiveRecord::Migration[8.1]
  def change
    add_column :job_listings, :about_company, :text
    add_column :job_listings, :company_culture, :text
  end
end
