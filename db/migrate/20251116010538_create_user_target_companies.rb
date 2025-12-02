class CreateUserTargetCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :user_target_companies do |t|
      t.references :user, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.integer :priority

      t.timestamps
    end

    add_index :user_target_companies, [ :user_id, :company_id ], unique: true
  end
end
