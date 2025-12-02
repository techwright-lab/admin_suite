class RemoveUniqueConstraintFromConnectedAccountsUserProvider < ActiveRecord::Migration[8.1]
  def change
    # Remove unique index on user_id + provider to allow multiple Google accounts per user
    remove_index :connected_accounts, name: "index_connected_accounts_on_user_id_and_provider"

    # Add non-unique index for performance (queries by user_id and provider)
    add_index :connected_accounts, [ :user_id, :provider ], name: "index_connected_accounts_on_user_id_and_provider"
  end
end
