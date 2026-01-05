# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Billing::Plan management.
    class BillingPlanResource < Admin::Base::Resource
      model ::Billing::Plan
      portal :payments
      section :catalog

      index do
        searchable :key, :name, :plan_type
        sortable :name, :key, :updated_at, default: :updated_at
        paginate 50

        columns do
          column :key
          column :name
          column :plan_type, header: "Type"
          column :interval
          column :amount_cents, header: "Amount (cents)"
          column :currency
          column :published
          column :updated_at, ->(p) { p.updated_at&.strftime("%b %d, %H:%M") }
        end

        filters do
          filter :plan_type, type: :select, label: "Type", options: [
            [ "All", "" ],
            [ "Free", "free" ],
            [ "Recurring", "recurring" ],
            [ "One-time", "one_time" ]
          ]
          filter :published, type: :select, label: "Published", options: [
            [ "All", "" ],
            [ "Published", "true" ],
            [ "Unpublished", "false" ]
          ]
        end
      end

      form do
        section "Plan" do
          row cols: 2 do
            field :key, required: true, help: "Stable identifier used for gating and pricing surfaces."
            field :name, required: true
          end

          field :description, type: :textarea, rows: 3

          row cols: 3 do
            field :plan_type, type: :select, required: true, collection: ::Billing::Plan::PLAN_TYPES.map { |v| [ v.humanize, v ] }
            field :interval, type: :select, collection: [ [ "", "" ] ] + ::Billing::Plan::INTERVALS.map { |v| [ v.humanize, v ] }
            field :currency, required: true, placeholder: "eur"
          end

          row cols: 3 do
            field :amount_cents, type: :number, placeholder: "e.g. 1200"
            field :sort_order, type: :number
            field :highlighted, type: :toggle
          end

          field :published, type: :toggle
          field :metadata, type: :json, help: "Free-form plan metadata (e.g. marketing copy variants)."
        end
      end
    end
  end
end


