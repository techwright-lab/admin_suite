---
name: Billing Settings Tabs
overview: "Redesign billing settings with two sub-tabs: Subscription (current plan, insight trial banner, upgrade options, management) and Billing (payment history, invoices). Account for insight-triggered trial via EntitlementGrant."
todos:
  - id: entitlements-extend
    content: Extend Entitlements service with insight trial helpers and quota usage methods
    status: completed
  - id: ls-portal-api
    content: Add customer_portal_url, cancel_subscription, resume_subscription to LemonSqueezy provider
    status: completed
  - id: subscription-controller
    content: Create Billing::SubscriptionsController with cancel/resume actions
    status: completed
  - id: portal-controller
    content: Create Billing::PortalController to redirect to LemonSqueezy customer portal
    status: completed
  - id: settings-controller
    content: Update SettingsController to load billing data and handle subtab param
    status: completed
  - id: billing-subtabs
    content: Redesign _billing.html.erb with sub-tab navigation (Subscription/Billing)
    status: completed
  - id: subscription-partial
    content: Create billing/_subscription.html.erb with trial banner, current plan, usage, upgrade options
    status: completed
    dependencies:
      - entitlements-extend
      - billing-subtabs
  - id: history-partial
    content: Create billing/_history.html.erb with payment method and billing history
    status: completed
    dependencies:
      - billing-subtabs
  - id: routes
    content: Add billing subscription management routes (cancel, resume, portal)
    status: completed
---

# Billing Settings Enhancement with Sub-Tabs

## Understanding the Insight-Triggered Trial

The trial is **not** a traditional provider trial. It's an internal `Billing::EntitlementGrant`:

```ruby
# From TrialUnlockService
source: "trial"
reason: "insight_triggered"
expires_at: 72.hours.from_now
entitlements: { cv_full_analysis, pattern_detection, assistant_access, ai_summaries (limit: 25), ... }
```

Triggered by user actions (first feedback after CV, 2 interviews, or AI synthesis). Once per lifetime.

## Proposed Layout: Two Sub-Tabs

### Tab 1: Subscription

```javascript
+--------------------------------------------------+
| INSIGHT TRIAL BANNER (if active EntitlementGrant)|
|  You've unlocked Pro features for 72 hours       |
|  ⏱ 47 hours remaining · Upgrade to keep access   |
+--------------------------------------------------+
| YOUR PLAN                                        |
|  [Pro Badge] Pro Monthly                         |
|  Status: Active · Renews Feb 4, 2026             |
|  ────────────────────────────────────────────    |
|  [Manage Payment Method]  [Cancel Subscription]  |
+--------------------------------------------------+
| USAGE THIS PERIOD                                |
|  AI Summaries    ████████░░  40/50               |
|  Assistant Msgs  ██████░░░░  30/50               |
+--------------------------------------------------+
| CHANGE PLAN                                      |
|  [Free]  [Pro ✓ Current]  [Sprint]               |
+--------------------------------------------------+
```



### Tab 2: Billing

```javascript
+--------------------------------------------------+
| PAYMENT METHOD                                   |
|  Visa •••• 4242 · Expires 12/26                  |
|  [Update via LemonSqueezy →]                     |
+--------------------------------------------------+
| BILLING HISTORY                                  |
|  Feb 4, 2026  Pro Monthly  $12.00  [Receipt]     |
|  Jan 4, 2026  Pro Monthly  $12.00  [Receipt]     |
|  Dec 4, 2025  Pro Monthly  $12.00  [Receipt]     |
+--------------------------------------------------+
```



## Implementation

### 1. Extend Entitlements Service

Add to [`app/services/billing/entitlements.rb`](app/services/billing/entitlements.rb):

```ruby
# Make active_subscription public
attr_reader :active_subscription

# New methods
def insight_trial_grant
  @insight_trial_grant ||= Billing::EntitlementGrant
    .where(user: user, source: "trial", reason: "insight_triggered")
    .active_at(at)
    .first
end

def insight_trial_active?
  insight_trial_grant.present?
end

def insight_trial_expires_at
  insight_trial_grant&.expires_at
end

def insight_trial_time_remaining
  return nil unless insight_trial_active?
  [(insight_trial_expires_at - Time.current).to_i, 0].max
end

def subscription_status
  return :trial if insight_trial_active? && active_subscription.nil?
  return :free if active_subscription.nil?
  active_subscription.status.to_sym
end

def quota_usage
  # Returns hash of { feature_key => { used: X, limit: Y, remaining: Z } }
end
```



### 2. Add LemonSqueezy Customer Portal

Extend [`app/services/billing/providers/lemon_squeezy.rb`](app/services/billing/providers/lemon_squeezy.rb):

```ruby
def customer_portal_url(customer:)
  # LemonSqueezy API: POST /v1/customers/:id/portal
  # Returns: { data: { attributes: { url: "https://..." } } }
end
```



### 3. Create Subscription Management Controller

New [`app/controllers/billing/subscriptions_controller.rb`](app/controllers/billing/subscriptions_controller.rb):

```ruby
class Billing::SubscriptionsController < ApplicationController
  # POST /billing/subscription/cancel
  def cancel
    # Set cancel_at_period_end via LemonSqueezy API
  end

  # POST /billing/subscription/resume  
  def resume
    # Remove cancellation via LemonSqueezy API
  end
end
```



### 4. Create Portal Redirect Controller

New [`app/controllers/billing/portal_controller.rb`](app/controllers/billing/portal_controller.rb):

```ruby
class Billing::PortalController < ApplicationController
  # GET /billing/portal
  def show
    url = Billing::Providers::LemonSqueezy.new.customer_portal_url(customer: current_customer)
    redirect_to url, allow_other_host: true
  end
end
```



### 5. Update Settings Controller

Update [`app/controllers/settings_controller.rb`](app/controllers/settings_controller.rb):

```ruby
def show
  @active_tab = params[:tab] || "profile"
  
  if @active_tab == "billing"
    @billing_subtab = params[:subtab] || "subscription"
    @entitlements = Billing::Entitlements.for(@user)
    @plans = Billing::Catalog.published_plans
    @quota_features = load_quota_features
    @billing_history = load_billing_history if @billing_subtab == "billing"
  end
  # ... rest
end
```



### 6. Redesign Billing Partial with Sub-Tabs

Rewrite [`app/views/settings/_billing.html.erb`](app/views/settings/_billing.html.erb):

```erb
<%# Sub-tab navigation %>
<div class="border-b border-gray-200 dark:border-gray-700 mb-6">
  <nav class="flex gap-4">
    <%= link_to "Subscription", settings_path(tab: "billing", subtab: "subscription"),
        class: subtab_class("subscription") %>
    <%= link_to "Billing", settings_path(tab: "billing", subtab: "billing"),
        class: subtab_class("billing") %>
  </nav>
</div>

<% if @billing_subtab == "subscription" %>
  <%= render "settings/billing/subscription", entitlements: @entitlements, plans: @plans %>
<% else %>
  <%= render "settings/billing/history", history: @billing_history %>
<% end %>
```



### 7. Create Sub-Tab Partials

**[`app/views/settings/billing/_subscription.html.erb`](app/views/settings/billing/_subscription.html.erb)**:

- Insight trial banner (conditional on `entitlements.insight_trial_active?`)
- Current plan card with status
- Usage dashboard for quota features
- Plan comparison grid

**[`app/views/settings/billing/_history.html.erb`](app/views/settings/billing/_history.html.erb)**:

- Payment method display
- Billing history table
- Invoice/receipt download links

### 8. Add Routes

Add to [`config/routes/application.rb`](config/routes/application.rb):

```ruby
namespace :billing do
  resource :subscription, only: [] do
    post :cancel
    post :resume
  end
  get :portal, to: "portal#show"
end
```



## File Changes Summary

| File | Change ||------|--------|| `app/services/billing/entitlements.rb` | Add insight trial helpers, quota usage, public accessors || `app/services/billing/providers/lemon_squeezy.rb` | Add `customer_portal_url`, `cancel_subscription`, `resume_subscription` || `app/controllers/billing/subscriptions_controller.rb` | **New**: cancel/resume actions || `app/controllers/billing/portal_controller.rb` | **New**: redirect to LS portal || `app/controllers/settings_controller.rb` | Load billing data, handle subtab param || `app/views/settings/_billing.html.erb` | Sub-tab navigation + conditional rendering || `app/views/settings/billing/_subscription.html.erb` | **New**: trial banner, plan, usage, upgrade || `app/views/settings/billing/_history.html.erb` | **New**: payment method, history table |