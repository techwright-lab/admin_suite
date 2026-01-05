# frozen_string_literal: true

class CreateBillingCatalog < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_plans do |t|
      t.uuid :uuid, null: false

      t.string :key, null: false
      t.string :name, null: false
      t.text :description

      t.string :plan_type, null: false # free, recurring, one_time
      t.string :interval # month, year (recurring only)

      t.integer :amount_cents # recurring/one_time only
      t.string :currency, default: "eur", null: false

      t.boolean :highlighted, default: false, null: false
      t.boolean :published, default: false, null: false
      t.integer :sort_order, default: 0, null: false

      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :billing_plans, :uuid, unique: true
    add_index :billing_plans, :key, unique: true
    add_index :billing_plans, :published
    add_index :billing_plans, [ :published, :sort_order ]

    create_table :billing_features do |t|
      t.uuid :uuid, null: false

      t.string :key, null: false
      t.string :name, null: false
      t.text :description

      t.string :kind, null: false # boolean, quota
      t.string :unit
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :billing_features, :uuid, unique: true
    add_index :billing_features, :key, unique: true

    create_table :billing_plan_entitlements do |t|
      t.references :plan, null: false, foreign_key: { to_table: :billing_plans }
      t.references :feature, null: false, foreign_key: { to_table: :billing_features }

      t.boolean :enabled, default: true, null: false
      t.integer :limit
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :billing_plan_entitlements, [ :plan_id, :feature_id ], unique: true, name: "index_billing_plan_entitlements_on_plan_and_feature"

    create_table :billing_provider_mappings do |t|
      t.uuid :uuid, null: false

      t.references :plan, null: false, foreign_key: { to_table: :billing_plans }
      t.string :provider, null: false # lemonsqueezy, stripe, etc

      t.string :external_product_id
      t.string :external_variant_id
      t.string :external_price_id
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :billing_provider_mappings, :uuid, unique: true
    add_index :billing_provider_mappings, [ :provider, :plan_id ], unique: true, name: "index_billing_provider_mappings_on_provider_and_plan"
  end
end
