# frozen_string_literal: true

AdminSuite.portal :payments do
  label "Payments Portal"
  icon "credit-card"
  color :emerald
  order 50
  description "Billing plans, subscriptions, and webhooks"

  dashboard do
    row do
      stat_panel "Plans", -> { Billing::Plan.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Features", -> { Billing::Feature.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Entitlements", -> { Billing::PlanEntitlement.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Mappings", -> { Billing::ProviderMapping.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Subscriptions", -> { Billing::Subscription.count }, span: 2, variant: :mini, color: :cyan
      stat_panel "Webhook Pending", -> { Billing::WebhookEvent.where(status: "pending").count }, span: 2, variant: :mini, color: :amber
    end

    row do
      cards_panel "Billing Management",
        span: 12,
        resources: [
          { resource_name: "billing_plans", label: "Plans", description: "Subscription plans", icon: "package", count: -> { Billing::Plan.count } },
          { resource_name: "billing_features", label: "Features", description: "Entitlement features", icon: "badge-check", count: -> { Billing::Feature.count } },
          { resource_name: "billing_subscriptions", label: "Subscriptions", description: "Customer subscriptions", icon: "receipt", count: -> { Billing::Subscription.count } },
          { resource_name: "billing_webhook_events", label: "Webhook Events", description: "Incoming provider webhooks", icon: "webhook", count: -> { Billing::WebhookEvent.count } }
        ]
    end
  end
end
