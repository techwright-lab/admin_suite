class AddIsAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :is_admin, :boolean, default: false, null: false
    add_index :users, :is_admin
  end
end
