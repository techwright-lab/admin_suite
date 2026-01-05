# Billing & Subscriptions (LemonSqueezy) — Setup & Operations

This document describes how billing/subscriptions work in Gleania, how to seed the initial catalog, how to configure LemonSqueezy, and what to monitor in production.

## Catalog model (Plans → Features → Entitlements)

- **Plans** (`Billing::Plan`): Free / Pro / Sprint (and internal plans). Plan records drive pricing UI and default entitlements.
- **Features** (`Billing::Feature`): Boolean gates and quota gates.
- **Plan entitlements** (`Billing::PlanEntitlement`): Join table that defines feature enablement and quota limits per plan.
- **Provider mappings** (`Billing::ProviderMapping`): Maps internal plan keys to provider IDs (LemonSqueezy variants).

The app reads pricing plans via `Billing::Catalog.published_plans`. Catalog records purge cache after commits so changes in the developer portal reflect quickly.

## Runtime model (Subscriptions / Grants / Usage)

- **Subscriptions** (`Billing::Subscription`): Provider-synced subscription state (LemonSqueezy webhooks populate this).
- **Entitlement grants** (`Billing::EntitlementGrant`): Time-bounded overrides for trials/promos/admin access. Stores an `entitlements` JSON map keyed by feature key.
- **Usage counters** (`Billing::UsageCounter`): Usage tracking for quota features (calendar-month windows for v1).

Entitlements are evaluated via `Billing::Entitlements.for(user)` by merging:
1) the user’s active subscription plan entitlements (or Free fallback), then
2) any active grants, then
3) usage counters for remaining quota.

## Seed initial billing data (required to start)

We ship an **idempotent billing catalog seed**:

- Seed file: `db/seeds/billing_catalog.rb`
- Service: `Billing::SeedCatalogService`
- Rake task: `rake db:seed:billing`

Run:

```bash
bin/rails db:seed:billing
```

This creates/updates:
- Plans: `free`, `pro_monthly`, `sprint_one_time`, `admin_developer` (internal)
- Features: core gating + quotas (`interviews`, `ai_summaries`, etc.)
- Plan entitlements for Free/Pro/Sprint

## Existing users → Free plan

We do **not** write per-user “free subscriptions”.

All users default to the Free plan by entitlement evaluation fallback:
- `Billing::Entitlements#plan` uses the active subscription plan if present, otherwise `Billing::Plan.find_by(key: "free")`.

So “migrating existing users” = ensuring the Free plan exists (the seed does this).

## Admin/Developer plan (unrestricted access)

We implement staff/admin access as an **entitlement grant** that enables every known `Billing::Feature`:

- Service: `Billing::AdminAccessService`
- Grant type: `Billing::EntitlementGrant` with `source: "admin"`, `reason: "admin_developer"`
- Expiry: represented as a far-future expiry (entitlement grants require `expires_at`).

### Grant/Revoke from Developer Portal

In the Developer Portal:
- Go to **Ops → Users → (user)**  
- Use actions:
  - **Grant Billing Admin Access**
  - **Revoke Billing Admin Access**

### Grant/Revoke from CLI

```bash
rake billing:grant_admin_access[email@example.com]
rake billing:revoke_admin_access[email@example.com]
```

## LemonSqueezy setup

### 1) Create products/variants in LemonSqueezy

Create variants that correspond to internal plan keys:
- `pro_monthly` (recurring monthly)
- `sprint_one_time` (one-time)

### 2) Configure Rails credentials

Add these credentials:
- `lemon_squeezy.api_key`
- `lemon_squeezy.store_id`
- `lemon_squeezy.webhook_secret`

Example (local):

```bash
bin/rails credentials:edit
```

```yml
lemon_squeezy:
  api_key: "..."
  store_id: "..."
  webhook_secret: "..."
```

### 3) Provider mappings (internal → LemonSqueezy)

In Developer Portal:
- **Payments → Provider Mappings**
- Create mappings for:
  - `pro_monthly` → LemonSqueezy variant ID
  - `sprint_one_time` → LemonSqueezy variant ID

### 4) Webhook endpoint

Set LemonSqueezy webhook target to:
- `POST /webhooks/lemon_squeezy`

Ensure the signing secret matches `lemon_squeezy.webhook_secret`.

### 5) Verify checkout return URL

Checkout creation uses:
- `Billing::Providers::LemonSqueezy#create_checkout`
- return URL back to Settings → Billing

Make sure `action_mailer.default_url_options[:host]` is set correctly for production.

### 6) Optional: post-checkout redirect URL with order params (UX only)

LemonSqueezy supports placeholders you can include in product/checkout links (e.g. confirmation/receipt buttons) such as `order_id`, `order_identifier`, `email`, and `total`.

Recommended:
- Set your confirmation/receipt button URL to:
  - `/billing/return?order_id=[order_id]&order_identifier=[order_identifier]&email=[email]&total=[total]`

We provide `GET /billing/return` which shows a friendly “processing” message and displays order details for support/debugging.

Important: **Do not rely on this redirect for fulfillment**—plan activation must still rely on webhooks.

Reference: [LemonSqueezy link variables](https://docs.lemonsqueezy.com/help/products/link-variables)

## Production monitoring & observability (recommended)

### Dashboards / UI

- **Payments Portal dashboard**: plans/features/subscriptions/webhook events
- **Webhook events list**: monitor pending/failed events, use “Replay” for retry

### Alerts (recommended)

- **Failed webhook events** (count > 0 over 10 minutes)
- **Webhook processing job retries** / queue depth spikes
- **Checkout creation failures** (Sentry + logs)

### Logs (recommended)

Watch for structured log events:
- webhook receipt + signature failures
- webhook processing failures
- subscription state transitions
- checkout creation failures

### Runbooks (recommended)

- How to replay a webhook event
- How to repair a broken provider mapping
- How to grant/revoke admin billing access
- How to backfill a subscription for a user (manual mapping + replay)


