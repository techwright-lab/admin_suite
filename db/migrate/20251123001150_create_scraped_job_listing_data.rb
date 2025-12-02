class CreateScrapedJobListingData < ActiveRecord::Migration[8.1]
  def change
    create_table :scraped_job_listing_data do |t|
      t.references :job_listing, null: false, foreign_key: true
      t.references :scraping_attempt, null: true, foreign_key: true
      t.string :url, null: false
      t.text :html_content
      t.text :cleaned_html
      t.integer :http_status
      t.string :content_hash
      t.datetime :valid_until, null: false
      t.jsonb :fetch_metadata, default: {}

      t.timestamps
    end

    add_index :scraped_job_listing_data, :url
    add_index :scraped_job_listing_data, :content_hash
    add_index :scraped_job_listing_data, :valid_until
    add_index :scraped_job_listing_data, [ :url, :valid_until ]
  end
end
