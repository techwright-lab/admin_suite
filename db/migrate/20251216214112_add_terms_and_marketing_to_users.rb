class AddTermsAndMarketingToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :terms_accepted_at, :datetime
    add_column :users, :marketing_opt_in, :boolean, default: false, null: false
  end
end
