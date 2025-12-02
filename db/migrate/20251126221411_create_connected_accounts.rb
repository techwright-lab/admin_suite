class CreateConnectedAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :connected_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      t.string :scopes
      t.string :email
      t.datetime :last_synced_at
      t.boolean :sync_enabled, default: true

      t.timestamps
    end

    add_index :connected_accounts, [ :user_id, :provider ], unique: true
    add_index :connected_accounts, [ :provider, :uid ], unique: true
  end
end
