class CreateJobListings < ActiveRecord::Migration[8.1]
  def change
    create_table :job_listings do |t|
      t.references :company, null: false, foreign_key: true
      t.references :job_role, null: false, foreign_key: true
      t.string :title
      t.string :url
      t.string :source_id
      t.string :job_board_id
      t.text :description
      t.text :requirements
      t.text :responsibilities
      t.decimal :salary_min, precision: 12, scale: 2
      t.decimal :salary_max, precision: 12, scale: 2
      t.string :salary_currency, default: "USD"
      t.text :equity_info
      t.text :benefits
      t.text :perks
      t.string :location
      t.integer :remote_type, default: 0
      t.integer :status, default: 0
      t.jsonb :custom_sections, default: {}
      t.jsonb :scraped_data, default: {}

      t.timestamps
    end

    add_index :job_listings, :status
    add_index :job_listings, :remote_type
    add_index :job_listings, [ :company_id, :job_role_id ]
  end
end
