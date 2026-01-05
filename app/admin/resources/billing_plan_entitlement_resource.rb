# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Billing::PlanEntitlement management.
    class BillingPlanEntitlementResource < Admin::Base::Resource
      model ::Billing::PlanEntitlement
      portal :payments
      section :catalog

      index do
        searchable :enabled
        sortable :updated_at, default: :updated_at
        paginate 50

        columns do
          column :plan, ->(e) { e.plan&.key }, header: "Plan"
          column :feature, ->(e) { e.feature&.key }, header: "Feature"
          column :enabled
          column :limit
          column :updated_at, ->(e) { e.updated_at&.strftime("%b %d, %H:%M") }
        end
      end

      form do
        section "Entitlement" do
          field :plan_id, type: :select, required: true,
                collection: -> { ::Billing::Plan.ordered.pluck(:name, :id) }
          field :feature_id, type: :select, required: true,
                collection: -> { ::Billing::Feature.order(:key).pluck(:key, :id) }
          row cols: 2 do
            field :enabled, type: :toggle
            field :limit, type: :number, help: "Only used for quota features."
          end
          field :metadata, type: :json
        end
      end
    end
  end
end


