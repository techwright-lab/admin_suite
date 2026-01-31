# Signals contracts

This folder contains **contract-first** artifacts for the email workflow planner:

- **Facts** produces a `DecisionInput` (event + match + application snapshot + extracted `EmailFacts`).
- **Decision** consumes `DecisionInput` and emits a strict `DecisionPlan` (planner-only; no side effects).
- **Execution** validates + applies the plan with guardrails.

If a shape is not validated at the boundary, it should not flow deeper into the system.

## Layout

- `schemas/`
  - Draft 2020-12 JSON Schemas for `DecisionInput` and `DecisionPlan`
  - Component schemas under `schemas/components/*`
- `examples/`
  - JSON fixtures for `decision_input/*` and `decision_plan/*`

## `$id` and `$ref` conventions

Schemas use stable `$id` URIs with the `gleania://` scheme, for example:

- `gleania://signals/contracts/schemas/decision_input.schema.json`

Refs should use these URIs (not relative paths). The runtime validator resolves these URIs to files under:

- `app/domains/signals/contracts/schemas/`

## Validation

Validation happens in two layers:

1) **Schema validation** (JSON Schema): types, required fields, enums, `additionalProperties: false`, etc.
2) **Semantic validation** (execution guardrails): evidence substring checks, resolvable targets, AASM checks, idempotency, confidence gates.

