class AddPlanToEntitlementGrants < ActiveRecord::Migration[8.1]
  def change
    add_column :billing_entitlement_grants, :billing_plan_id, :bigint
    add_index :billing_entitlement_grants, :billing_plan_id
    add_foreign_key :billing_entitlement_grants, :billing_plans, column: :billing_plan_id, on_delete: :nullify
  end
end
