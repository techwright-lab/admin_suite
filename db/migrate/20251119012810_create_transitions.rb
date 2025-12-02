class CreateTransitions < ActiveRecord::Migration[8.1]
  def change
    create_table :transitions do |t|
      t.string :event
      t.string :action
      t.belongs_to :resource, polymorphic: true, null: false
      t.string :from_state
      t.string :to_state

      t.timestamps
    end
  end
end
