# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Billing::ProviderMapping management.
    class BillingProviderMappingResource < Admin::Base::Resource
      model ::Billing::ProviderMapping
      portal :payments
      section :providers

      index do
        searchable :provider, :external_product_id, :external_variant_id
        sortable :updated_at, default: :updated_at
        paginate 50

        columns do
          column :provider
          column :plan, ->(m) { m.plan&.key }, header: "Plan"
          column :external_product_id, header: "Product"
          column :external_variant_id, header: "Variant"
          column :updated_at, ->(m) { m.updated_at&.strftime("%b %d, %H:%M") }
        end
      end

      form do
        section "Provider Mapping" do
          field :plan_id, type: :select, required: true,
                collection: -> { ::Billing::Plan.ordered.pluck(:name, :id) }
          row cols: 2 do
            field :provider, type: :select, required: true, collection: ::Billing::ProviderMapping::PROVIDERS.map { |v| [ v.humanize, v ] }
            field :external_product_id, placeholder: "LemonSqueezy product id"
          end
          row cols: 2 do
            field :external_variant_id, placeholder: "LemonSqueezy variant id"
            field :external_price_id, placeholder: "Optional price id"
          end
          field :metadata, type: :json, help: "Provider-specific config (e.g., store_id for LemonSqueezy)."
        end
      end
    end
  end
end


