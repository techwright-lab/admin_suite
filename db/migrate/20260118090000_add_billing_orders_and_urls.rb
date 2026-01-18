# frozen_string_literal: true

class AddBillingOrdersAndUrls < ActiveRecord::Migration[8.1]
  def change
    add_column :billing_customers, :urls, :jsonb, default: {}, null: false
    add_column :billing_subscriptions, :urls, :jsonb, default: {}, null: false

    create_table :billing_orders do |t|
      t.uuid :uuid, null: false
      t.references :user, null: false, foreign_key: true
      t.references :billing_customer, null: true, foreign_key: { to_table: :billing_customers }
      t.references :billing_subscription, null: true, foreign_key: { to_table: :billing_subscriptions }

      t.string :provider, null: false
      t.string :external_order_id, null: false
      t.string :status
      t.integer :total_cents
      t.string :currency
      t.string :order_number
      t.string :identifier
      t.string :receipt_url
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end

    add_index :billing_orders, :uuid, unique: true
    add_index :billing_orders, [ :provider, :external_order_id ], unique: true
    add_index :billing_orders, [ :provider, :user_id ]
  end
end
