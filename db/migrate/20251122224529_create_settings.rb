class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.text :description
      t.string :name
      t.boolean :value

      t.timestamps
    end
  end
end
