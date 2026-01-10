# frozen_string_literal: true

class CreateUserTargetDomains < ActiveRecord::Migration[8.1]
  def change
    create_table :user_target_domains do |t|
      t.references :user, null: false, foreign_key: true
      t.references :domain, null: false, foreign_key: true
      t.integer :priority

      t.timestamps
    end

    add_index :user_target_domains, [:user_id, :domain_id], unique: true, name: "idx_user_target_domains_unique"
  end
end
