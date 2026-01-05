# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Billing::Subscription viewing (read-only via routes).
    class BillingSubscriptionResource < Admin::Base::Resource
      model ::Billing::Subscription
      portal :payments
      section :runtime

      index do
        searchable :provider, :status, :external_subscription_id
        sortable :updated_at, :created_at, default: :updated_at
        paginate 50

        columns do
          column :user_id, header: "User ID"
          column :provider
          column :status
          column :plan, ->(s) { s.plan&.key }, header: "Plan"
          column :external_subscription_id, header: "External ID"
          column :current_period_ends_at
          column :updated_at, ->(s) { s.updated_at&.strftime("%b %d, %H:%M") }
        end
      end

      show do
        sidebar do
          panel :status, title: "Status", fields: [ :status, :provider, :external_subscription_id ]
          panel :timing, title: "Timing", fields: [ :trial_ends_at, :current_period_starts_at, :current_period_ends_at, :cancel_at_period_end, :cancelled_at ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at, :updated_at ]
        end

        main do
          panel :metadata, title: "Metadata", fields: [ :metadata ]
        end
      end
    end
  end
end


