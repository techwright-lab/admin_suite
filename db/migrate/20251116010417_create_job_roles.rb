class CreateJobRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :job_roles do |t|
      t.string :title
      t.string :category
      t.text :description

      t.timestamps
    end
    add_index :job_roles, :title, unique: true
  end
end
