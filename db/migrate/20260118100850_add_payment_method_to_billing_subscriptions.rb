class AddPaymentMethodToBillingSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :billing_subscriptions, :card_brand, :string
    add_column :billing_subscriptions, :card_last_four, :string
  end
end
