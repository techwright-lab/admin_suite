class AddEmailVerificationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_verified_at, :datetime
    add_column :users, :oauth_provider, :string
    add_column :users, :oauth_uid, :string
    add_index :users, [:oauth_provider, :oauth_uid], unique: true
  end
end
