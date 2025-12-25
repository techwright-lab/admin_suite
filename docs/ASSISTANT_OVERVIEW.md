# Assistant Overview (Chat + Tool Calling)

This document explains how the Gleania Assistant works, where the code lives, and how the main pieces fit together.

## High-level goals

- Provide a **first-class assistant chat** inside the app (dedicated pages + floating widget).
- Enable **internal tool calling** to read from / write to the Gleania domain (with strict validation + auth).
- Make the system **observable** (traceable end-to-end), **safe** (two-phase confirmation for writes), and **resilient** (idempotency + timeouts + async jobs).

## Key concepts

- **Thread**: a conversation for one user (`Assistant::ChatThread`).
- **Message**: a single utterance (`Assistant::ChatMessage`, role: `user` / `assistant` / `tool`).
- **Turn**: one “question → answer (+ tool proposals)” cycle (`Assistant::Turn`).
- **Tool execution**: an audited record representing a proposed/executed tool call (`Assistant::ToolExecution`).
- **Event**: structured, append-only observability record (`Assistant::Ops::Event`).
- **trace_id**: correlation id for a single turn/tool run; shows up in turns/tool executions/events and is used for debugging.
- **uuid**: stable external identifier for assistant records (safe for URLs/logging).

## Folder layout (boundaries)

Assistant code is namespaced and separated under:

- `app/domains/assistant/`
  - `models/` (threads, messages, turns, tool executions, events, memory)
  - `services/` (orchestrator, context builder, tool runner)
  - `tools/` (tool implementations)
  - `policies/` (tool allow/deny logic)

User-facing UI:

- `app/controllers/assistant/**`
- `app/views/assistant/**`

Admin ops UI (custom admin, not Avo):

- `app/controllers/admin/assistant_*`
- `app/views/admin/assistant_*`

## Runtime flow (one chat send)

1. User submits a message from `/assistant/threads/:uuid` or from the widget.
2. `Assistant::MessagesController` calls `Assistant::Chat::Orchestrator`.
3. Orchestrator:
   - persists the user message
   - builds a context snapshot (`Assistant::Context::Builder`)
   - selects allowed tools (`Assistant::ToolPolicy`)
   - calls the LLM (provider fallback)
   - persists assistant message + turn record
   - records tool proposals as `Assistant::ToolExecution` rows (`status: proposed`)
4. Post-commit background work:
   - summarization job
   - memory proposal job
   - auto-enqueue read-only tool executions
5. Tool executions run via `AssistantToolExecutionJob` (async) and use `Assistant::Tools::Runner` for guardrails.

## Safety + resilience

- **Two-phase confirmation**: write tools are proposed first, must be approved, then executed.
- **Schema validation**: tool args are validated against `assistant_tools.arg_schema`.
- **Authorization**: tool runner enforces user/thread scoping server-side.
- **Timeouts**: per-tool `timeout_ms`.
- **Idempotency**:
  - chat sends: `assistant_turns.client_request_uuid` (unique per thread)
  - tool executions: `assistant_tool_executions.idempotency_key`
  - admin replay: `(replay_of_id, replay_request_uuid)` uniqueness

## Observability

- `Ai::LlmApiLog` stores provider/model/tokens and assistant outputs for assistant operations.
- `Assistant::Turn` links a chat turn to an `Ai::LlmApiLog` row.
- `Assistant::Ops::Event` records structured events for ops actions and tool runner outcomes.
- Custom admin pages allow inspection by thread/turn/tool execution and filtering by `trace_id`.

