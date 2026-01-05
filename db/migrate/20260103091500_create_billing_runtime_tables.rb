# frozen_string_literal: true

class CreateBillingRuntimeTables < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_customers do |t|
      t.uuid :uuid, null: false
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :external_customer_id
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end

    add_index :billing_customers, :uuid, unique: true
    add_index :billing_customers, [ :provider, :user_id ], unique: true
    add_index :billing_customers, [ :provider, :external_customer_id ], unique: true

    create_table :billing_subscriptions do |t|
      t.uuid :uuid, null: false
      t.references :user, null: false, foreign_key: true
      t.references :plan, null: true, foreign_key: { to_table: :billing_plans }

      t.string :provider, null: false
      t.string :external_subscription_id
      t.string :status, null: false, default: "inactive"

      t.datetime :current_period_starts_at
      t.datetime :current_period_ends_at
      t.datetime :trial_ends_at

      t.boolean :cancel_at_period_end, default: false, null: false
      t.datetime :cancelled_at

      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end

    add_index :billing_subscriptions, :uuid, unique: true
    add_index :billing_subscriptions, [ :provider, :user_id ]
    add_index :billing_subscriptions, [ :provider, :external_subscription_id ], unique: true
    add_index :billing_subscriptions, [ :user_id, :status ]
    add_index :billing_subscriptions, :current_period_ends_at

    create_table :billing_entitlement_grants do |t|
      t.uuid :uuid, null: false
      t.references :user, null: false, foreign_key: true

      t.string :source, null: false # trial, admin, promo
      t.string :reason

      t.datetime :starts_at, null: false
      t.datetime :expires_at, null: false

      # Map of feature_key -> { enabled: bool, limit: int }
      t.jsonb :entitlements, default: {}, null: false

      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end

    add_index :billing_entitlement_grants, :uuid, unique: true
    add_index :billing_entitlement_grants, [ :user_id, :starts_at, :expires_at ]
    add_index :billing_entitlement_grants, [ :user_id, :source, :reason ]

    create_table :billing_usage_counters do |t|
      t.uuid :uuid, null: false
      t.references :user, null: false, foreign_key: true

      t.string :feature_key, null: false
      t.integer :used, null: false, default: 0

      t.datetime :period_starts_at, null: false
      t.datetime :period_ends_at, null: false

      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end

    add_index :billing_usage_counters, :uuid, unique: true
    add_index :billing_usage_counters, [ :user_id, :feature_key, :period_starts_at ], unique: true, name: "index_billing_usage_counters_on_user_feature_period"
    add_index :billing_usage_counters, [ :user_id, :feature_key ]
  end
end
