# Data Classification Policy

## Purpose

This policy defines how Gleania identifies and classifies data into protection levels, and the minimum safeguards required for each level. It supports security reviews and CASA Tier 2 assessment evidence.

## Scope

Applies to:
- Application code and data stores (PostgreSQL, Active Storage, logs)
- Third-party integrations (Google OAuth/Gmail, LLM providers, billing provider)
- CI/CD and deployment secrets (Rails encrypted credentials)

## Classification levels

### Level 1 — Public

**Definition**: Information intended for public consumption; disclosure causes no harm.

**Examples**:
- Public marketing content
- Public documentation intended for all users

**Minimum safeguards**:
- No special controls beyond normal integrity controls and change management

### Level 2 — Internal

**Definition**: Non-public business information; disclosure may cause minor operational impact.

**Examples**:
- Internal runbooks, operational procedures
- Non-sensitive application logs (sanitized)

**Minimum safeguards**:
- Access limited to staff with a business need
- No secrets in logs/tickets/PRs

### Level 3 — Confidential

**Definition**: User or business data that could cause harm if disclosed; requires strong access control and careful handling.

**Examples**:
- User profile data (name, email address, preferences)
- User-generated content (interview notes, reflections, emails content)
- Support ticket content and contact email

**Minimum safeguards**:
- Access restricted by role/need-to-know
- TLS for data in transit
- Sanitized logging (avoid content dumps unless explicitly required and protected)
- Retention defined; delete on request where applicable

### Level 4 — Restricted (Sensitive)

**Definition**: Highly sensitive security data or secrets; disclosure could lead to account compromise, fraud, or major impact.

**Examples**:
- Authentication material (password digests, session tokens)
- OAuth credentials (Google access/refresh tokens)
- API keys / secrets (OpenAI, Anthropic, Postmark, LemonSqueezy, Turnstile, Cloudflare)
- Rails encrypted credentials master key (`RAILS_MASTER_KEY`)
- Billing webhook secrets and provider tokens

**Minimum safeguards**:
- Strict least-privilege access
- Encryption at rest where supported (e.g., Active Record encryption for OAuth tokens)
- Secrets stored only in approved secret storage (Rails encrypted credentials + protected master key distribution)
- Never logged; never stored in plaintext in code, tickets, PRs, or chat
- Rotation procedures documented

## Identification and classification process

We classify data using:
- **Data Inventory** (`docs/security/DATA_INVENTORY.md`) mapping data elements → protection level
- Architectural reviews when adding new features/integrations (e.g., Gmail sync, billing, LLM features)

**When to update**:
- New data fields collected from users
- New third-party integration added
- New logs/telemetry introduced
- Changes to authentication/authorization flows

## Ownership and review cadence

- **Owner**: Engineering Lead / Security Owner (internal assignment)
- **Review cadence**: at least **annually**, and during significant feature/integration launches
- **Evidence**: updates tracked via git history of this policy + inventory

