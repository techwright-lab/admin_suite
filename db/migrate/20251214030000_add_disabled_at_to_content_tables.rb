class AddDisabledAtToContentTables < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :disabled_at, :datetime
    add_index :companies, :disabled_at

    add_column :job_roles, :disabled_at, :datetime
    add_index :job_roles, :disabled_at

    add_column :job_listings, :disabled_at, :datetime
    add_index :job_listings, :disabled_at

    add_column :skill_tags, :disabled_at, :datetime
    add_index :skill_tags, :disabled_at
  end
end
