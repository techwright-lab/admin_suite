# Data Inventory / Data Map

## Purpose

This inventory identifies and classifies sensitive data processed by Gleania into protection levels defined in `docs/security/DATA_CLASSIFICATION_POLICY.md`.

## Legend (Protection levels)

- **Public**
- **Internal**
- **Confidential**
- **Restricted**

## Inventory (application + integrations)

| Data element | Where it lives (examples) | Protection level | Why | Key protections (current) |
|---|---|---:|---|---|
| User authentication password hash (`password_digest`) | `users.password_digest` | **Restricted** | Credential material; compromise impacts accounts | `has_secure_password`; stored as digest; never displayed |
| User sessions (session IDs, metadata) | `sessions` table (e.g., `ip_address`, `user_agent`) | **Restricted** | Can facilitate session abuse and tracking | Server-side sessions; access restricted; avoid logging secrets |
| Password reset token (temporary) | Generated via `User.password_reset_token` (signed token); validated by `User.find_by_password_reset_token!` | **Restricted** | Grants ability to set a new password | Expires (15 minutes); invalid/expired tokens rejected; rate limited reset requests |
| Email verification token (temporary) | `User.generates_token_for :email_verification` | **Restricted** | Grants ability to verify/activate an email | Expires (24 hours); invalid/expired tokens rejected; resend rate limited |
| User email address | `users.email_address` | **Confidential** | PII | Access controlled; normalization; not exposed publicly |
| User profile fields (name, bio, links) | `users.*` (e.g., `name`, `bio`, social URLs) | **Confidential** | PII / user data | Access controlled; user-managed |
| Interview data and notes | `interview_applications`, `interview_rounds`, `interview_feedbacks`, related tables | **Confidential** | User-generated content; may include sensitive info | App authorization; least-privilege staff access; avoid logging content |
| Synced email content | `synced_emails` table (`body_html`, previews, metadata) | **Confidential** | User email content can contain sensitive data | Access controlled; treat as sensitive content; avoid logging full bodies |
| OAuth tokens (Google access/refresh tokens) | `connected_accounts.access_token`, `connected_accounts.refresh_token` | **Restricted** | Grants access to external accounts | Encrypted at rest via Active Record encryption (`encrypts :access_token`, `encrypts :refresh_token`) |
| OAuth identifiers | `connected_accounts.uid`, `users.oauth_provider`, `users.oauth_uid` | **Confidential** | Identifiers link to external accounts | Access controlled |
| Billing provider secrets (API keys, webhook secrets) | Rails encrypted credentials; injected via env (`config/deploy.yml` env secrets list) | **Restricted** | Can trigger billing actions / accept webhooks | Stored in Rails encrypted credentials; master key protected; never logged |
| Billing events payloads | `billing_webhook_events.payload` | **Confidential** (sometimes **Restricted**) | May include customer IDs, emails, receipt URLs, provider metadata | Access limited; avoid exporting; sanitize when sharing |
| Billing receipts / invoice URLs | `billing_orders.receipt_url`, `billing_subscriptions.latest_invoice_url` | **Confidential** | Links may grant access to documents | Stored in DB; UI opens in new tab; avoid sharing publicly |
| Payment method summary (brand/last4) | `billing_subscriptions.card_brand`, `card_last_four` | **Confidential** | Limited payment info; still sensitive | Stored only as last4 + brand; no full PAN |
| LLM prompts + model configuration | `llm_prompts`, `llm_provider_configs` | **Internal** / **Confidential** | Operational IP; may include sensitive instructions | Access controlled via developer portal |
| LLM request/response logs | `llm_api_logs` | **Confidential** (sometimes **Restricted**) | Can contain user content depending on logging | Access controlled; ensure redaction of secrets; retention managed |
| Application secrets & credentials master key | `RAILS_MASTER_KEY` (environment variable), encrypted files under `config/credentials*.yml.enc` | **Restricted** | Decrypts secrets; compromise is critical | Stored in access-controlled secret storage; never committed/logged |
| Support contact submissions | `support_tickets` (email, content) | **Confidential** | User communications/PII | Access controlled; retention managed |

## Notes

- **“Restricted”** includes any value that enables authentication, authorization, or third‑party access (password material, tokens, API keys).
- Items marked “sometimes Restricted” depend on whether payloads/logs include secrets; logging should be configured to avoid secrets wherever possible.

## Review cadence

- Review at least annually and during major feature/integration launches.
- Evidence is maintained via git history of this file.

