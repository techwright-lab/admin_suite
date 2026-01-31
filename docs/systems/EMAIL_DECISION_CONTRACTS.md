# Email decision contracts (Facts → Plan)

This document describes the **contract-first** design for email-driven workflow automation:

- **Facts**: extract and normalize structured `EmailFacts` from a synced email + application snapshot.
- **Decision**: read `DecisionInput` and emit a strict `DecisionPlan` (planner-only; no side effects).
- **Execution**: validate + apply the plan with guardrails (deterministic; DB writes happen here).

These contracts are stored in the app so they can be validated at runtime and in tests, but this doc lives in `docs/` so it can be viewed in the docs viewer.

## Where the contracts live

- **Schemas (Draft 2020-12 JSON Schema)**:
  - `app/domains/signals/contracts/schemas/decision_input.schema.json`
  - `app/domains/signals/contracts/schemas/decision_plan.schema.json`
  - Components:
    - `app/domains/signals/contracts/schemas/components/common/`
    - `app/domains/signals/contracts/schemas/components/event/`
    - `app/domains/signals/contracts/schemas/components/match/`
    - `app/domains/signals/contracts/schemas/components/application/`
    - `app/domains/signals/contracts/schemas/components/facts/`

- **Examples (fixtures)**:
  - `app/domains/signals/contracts/examples/decision_input/`
  - `app/domains/signals/contracts/examples/decision_plan/`

## Contract objects

### `DecisionInput`

Top-level schema:
- `app/domains/signals/contracts/schemas/decision_input.schema.json`

Contains:
- **event**: canonical email event (subject, from/to, canonical body text, extracted raw links)
- **match**: whether and how the email is matched to an `InterviewApplication`
- **application**: bounded snapshot of current application state + recent rounds
- **facts**: `EmailFacts` extracted for this event (single source of truth for decisioning)

### `EmailFacts`

Component schema:
- `app/domains/signals/contracts/schemas/components/facts/email_facts.schema.json`

Includes:
- **classification**: `kind` (coarse intent bucket) + evidence
- **entities**: company/recruiter/job fields
- **action_links**: useful URLs with labels + priority (replacement for prior signal URL extraction)
- **key_insights / is_forwarded**
- **scheduling** facts (including `round_type`)
- **round_feedback** facts (including `round_type`)
- **status_change** facts (rejection/offer/etc.)

### `DecisionPlan`

Top-level schema:
- `app/domains/signals/contracts/schemas/decision_plan.schema.json`

The planner emits:
- **decision**: `apply | noop | needs_review`
- **plan**: ordered steps from a fixed vocabulary (no prose)
- **evidence**: required for non-`noop` steps
- **preconditions**: strings describing what must be true at execution time

## Validation expectations

### Schema validation (shape)

All Facts and Decision outputs must validate against their JSON schemas:
- Facts output → `EmailFacts`
- Planner output → `DecisionPlan`
- Builder output → `DecisionInput`

Planner output should fail closed:
- `DecisionPlan` uses `additionalProperties: false`
- unknown actions are invalid
- missing required fields are invalid

### Semantic validation (meaning)

Schema validation is not sufficient for safety. Execution should also enforce:
- **evidence verification**: every evidence string must be a substring of the canonical email body
- **target resolvability**: round selectors like `latest_pending` or `by_scheduled_at_window` must resolve
- **AASM guards**: only apply status/stage transitions that are allowed for the current application state
- **idempotency**: avoid duplicate rounds/feedback/status updates for the same `synced_email_id`
- **confidence gating**: destructive actions (e.g., setting rejected/closed) require higher confidence

## Scenarios (fixtures)

Current example fixtures:
- Scheduling confirmed:
  - `app/domains/signals/contracts/examples/decision_input/scheduling_confirmed.json`
  - `app/domains/signals/contracts/examples/decision_plan/scheduling_confirmed.plan.json`
- Round feedback (passed):
  - `app/domains/signals/contracts/examples/decision_input/round_feedback_passed.json`
  - `app/domains/signals/contracts/examples/decision_plan/round_feedback_passed.plan.json`
- Rejection:
  - `app/domains/signals/contracts/examples/decision_input/rejection.json`
  - `app/domains/signals/contracts/examples/decision_plan/rejection.plan.json`
- Offer:
  - `app/domains/signals/contracts/examples/decision_input/offer.json`
  - `app/domains/signals/contracts/examples/decision_plan/offer.plan.json`

## Notes on taxonomy

- Keep `InterviewRound.stage` **coarse** (pipeline-level) and store granular round classification in `round_type` (string) and/or `InterviewRoundType` (model).
- Keep plan actions **strictly whitelisted**; add new actions by updating the enums + plan schema + executor guardrails + fixtures.

