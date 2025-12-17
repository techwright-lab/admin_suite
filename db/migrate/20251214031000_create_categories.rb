class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.integer :kind, null: false
      t.datetime :disabled_at

      t.timestamps
    end

    add_index :categories, :disabled_at
    add_index :categories, :kind
    add_index :categories, "LOWER(name), kind", unique: true, name: "index_categories_on_lower_name_and_kind"
  end
end
