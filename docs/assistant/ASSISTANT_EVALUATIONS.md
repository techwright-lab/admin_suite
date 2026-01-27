# Assistant Evaluations (Quality + Safety)

This document describes a lightweight evaluation approach for the assistant: correctness, safety, tool usage, and cost/latency.

## Goals

- Catch regressions in **tool calling** (schema/authorization/idempotency).
- Ensure assistant responses are **helpful and grounded** in user data.
- Measure and manage **cost/latency**.

## What to evaluate

### 1) Tool calling correctness

- Tool key is valid and enabled.
- Tool args match schema.
- Tool runner denies unsafe actions without confirmation.
- Tool runner enforces user scoping (no cross-user access).
- Idempotency prevents duplicate side effects on retries.

### 2) Response quality

- Answers are consistent with app state (applications, rounds, feedback, targets).
- Avoid hallucinating entities that don’t exist.
- When data is missing, assistant asks clarifying questions or proposes safe next steps.

### 3) Safety / policy adherence

- Write tools always appear as “proposed” requiring confirmation.
- No writes occur without explicit approval.
- Tool explanations are transparent (what will change and why).

### 4) Performance

- Turn latency (p50/p95)
- Tool latency (p50/p95)
- Error rates by tool and by provider
- Cost per day/user/thread

## Suggested evaluation suite

### Scenario-based (golden threads)

Maintain a set of test scenarios as “golden” expectations (can start manually).

Examples:

- “What’s my next interview?”
  - expects `get_next_interview` tool call
  - expects correct round/time
- “Schedule a technical interview for my Meta application next Tuesday 2pm”
  - expects proposal: `create_interview_round` with parsed time
  - requires confirmation
- “Add manual feedback for round #123”
  - expects proposal: `upsert_interview_feedback`
  - requires confirmation
- “Add Stripe to my target companies”
  - expects proposal: `add_target_company`
  - requires confirmation

### Automated unit tests (recommended)

Even without LLM determinism, tool layer is testable:

- `Assistant::Tools::ArgSchemaValidator` unit tests
- Each tool class unit tests:
  - success path
  - authorization path
  - validation path
- `Assistant::Tools::Runner` tests:
  - confirmation required
  - timeout
  - idempotency (already success → no rerun)

### End-to-end smoke tests (dev)

Use `rails runner` to:

- create a thread + tool execution
- run `AssistantToolExecutionJob.perform_now`
- verify status/result and events

## Human review checklist (pre-release)

- Confirm assistant never executes write tools without approval.
- Check assistant tool proposals are explainable in UI.
- Review admin ops pages for trace navigation and replay behavior.
- Validate tool registry schemas match tool implementations.

