class CreateUserTargetJobRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_target_job_roles do |t|
      t.references :user, null: false, foreign_key: true
      t.references :job_role, null: false, foreign_key: true
      t.integer :priority

      t.timestamps
    end

    add_index :user_target_job_roles, [ :user_id, :job_role_id ], unique: true
  end
end
