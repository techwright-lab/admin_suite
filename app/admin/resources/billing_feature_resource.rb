# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Billing::Feature management.
    class BillingFeatureResource < Admin::Base::Resource
      model ::Billing::Feature
      portal :payments
      section :catalog

      index do
        searchable :key, :name, :kind, :unit
        sortable :key, :updated_at, default: :updated_at
        paginate 50

        columns do
          column :key
          column :name
          column :kind
          column :unit
          column :updated_at, ->(f) { f.updated_at&.strftime("%b %d, %H:%M") }
        end
      end

      form do
        section "Feature" do
          row cols: 2 do
            field :key, required: true, help: "Stable identifier used by gating checks."
            field :name, required: true
          end
          row cols: 2 do
            field :kind, type: :select, required: true, collection: ::Billing::Feature::KINDS.map { |v| [ v.humanize, v ] }
            field :unit, placeholder: "e.g. ai_tokens, interviews"
          end
          field :description, type: :textarea, rows: 3
          field :metadata, type: :json
        end
      end
    end
  end
end


