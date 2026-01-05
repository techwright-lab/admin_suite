# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Billing::WebhookEvent viewing (read-only via routes).
    class BillingWebhookEventResource < Admin::Base::Resource
      model ::Billing::WebhookEvent
      portal :payments
      section :runtime

      index do
        searchable :provider, :event_type, :status, :idempotency_key
        sortable :received_at, :updated_at, default: :received_at, direction: :desc
        paginate 50

        columns do
          column :provider
          column :event_type, header: "Event"
          column :status
          column :received_at
          column :processed_at
          column :idempotency_key, header: "Key"
        end

        filters do
          filter :status, type: :select, label: "Status", options: [
            [ "All", "" ],
            [ "Pending", "pending" ],
            [ "Processed", "processed" ],
            [ "Failed", "failed" ],
            [ "Ignored", "ignored" ]
          ]
        end
      end

      show do
        sidebar do
          panel :status, title: "Status", fields: [ :provider, :event_type, :status, :received_at, :processed_at ]
          panel :error, title: "Error", fields: [ :error_message ]
        end

        main do
          panel :payload, title: "Payload", fields: [ :payload ]
        end
      end

      actions do
        action :replay, method: :post, label: "Replay"
      end
    end
  end
end


