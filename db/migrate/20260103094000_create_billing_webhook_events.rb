# frozen_string_literal: true

class CreateBillingWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_webhook_events do |t|
      t.uuid :uuid, null: false

      t.string :provider, null: false
      t.string :event_type
      t.string :idempotency_key, null: false

      t.jsonb :payload, default: {}, null: false

      t.string :status, null: false, default: "pending" # pending, processed, failed, ignored
      t.datetime :received_at, null: false
      t.datetime :processed_at
      t.text :error_message

      t.timestamps
    end

    add_index :billing_webhook_events, :uuid, unique: true
    add_index :billing_webhook_events, [ :provider, :idempotency_key ], unique: true
    add_index :billing_webhook_events, [ :provider, :status, :received_at ]
    add_index :billing_webhook_events, [ :provider, :event_type, :received_at ]
  end
end


