# frozen_string_literal: true

class CreateDomains < ActiveRecord::Migration[8.1]
  def change
    create_table :domains do |t|
      t.string :name, null: false
      t.string :slug
      t.text :description
      t.datetime :disabled_at

      t.timestamps
    end

    add_index :domains, :name, unique: true
    add_index :domains, :slug, unique: true
    add_index :domains, :disabled_at
  end
end
