class AddCurrentJobRoleAndCompanyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :current_job_role, foreign_key: { to_table: :job_roles }, index: true
    add_reference :users, :current_company, foreign_key: { to_table: :companies }, index: true

    # Remove old fields
    remove_column :users, :current_role, :string if column_exists?(:users, :current_role)
    remove_column :users, :target_roles, :text if column_exists?(:users, :target_roles)
  end
end
