class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name
      t.string :website
      t.text :about
      t.string :logo_url

      t.timestamps
    end
    add_index :companies, :name, unique: true
  end
end
