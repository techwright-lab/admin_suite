class AddReauthFieldsToConnectedAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :connected_accounts, :needs_reauth, :boolean, default: false, null: false
    add_column :connected_accounts, :auth_error_at, :datetime
    add_column :connected_accounts, :auth_error_message, :string
  end
end
