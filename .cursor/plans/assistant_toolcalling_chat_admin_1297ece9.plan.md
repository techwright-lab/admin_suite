---
name: assistant_toolcalling_chat_admin
overview: Add a first-class Assistant layer (chat + internal tool calling) with strong boundaries, full observability, and custom admin management for tools/prompts/executions. Use Turbo Streams for a hybrid UX (floating widget + dedicated chat pages).
todos:
  - id: assistant-domain-skeleton
    content: Create Assistant domain namespace and folder structure (models/services/tools/policies) with clear boundaries from existing app/services.
    status: completed
  - id: assistant-persistence
    content: Add Assistant threads/messages/tool execution tables and models; add trace_id correlation and references to Ai::LlmApiLog.
    status: completed
  - id: assistant-orchestrator
    content: "Implement assistant orchestrator: context pack builder, policy, LLM call via existing providers, tool proposal parsing, two-phase confirmation support."
    status: completed
  - id: tool-registry-and-runner
    content: Implement tool registry model + admin CRUD; implement ToolRunner with validation, auth, idempotency, timeouts, and structured results.
    status: completed
  - id: hybrid-ui-turbo
    content: Build floating widget + dedicated chat pages using Turbo Streams; implement propose/confirm UX and streaming assistant updates.
    status: completed
  - id: admin-ops-console
    content: Add custom admin section to inspect threads/turns/tool executions, enable/disable tools, replay executions, and view metrics/costs.
    status: completed
  - id: observability-hardening
    content: Extend Ai::LlmApiLog operation types for assistant; add dashboards/filters and structured logging for end-to-end tracing and resilience controls.
    status: completed
---

### Goals

- **Assistant chat** that answers questions about the user’s profile/skills/jobs and can **propose + execute actions** inside Gleania.
- **Internal tool calling** (no external MCP yet) with strict validation/authorization and **two-phase confirmation** for write actions.
- **Full observability** across assistant turns, tool proposals, and tool executions; manageable via **custom admin**.
- **Clean boundaries + namespacing** so the assistant layer can scale independently.

### Namespacing + folder layout (clear boundaries)

Create a dedicated top-level domain namespace:

- **`app/domains/assistant/`** (or `app/assistant/` if you prefer Rails-default; recommendation: `app/domains/assistant/` to keep boundaries obvious)
- `models/` (threads/messages/executions)
- `services/` (orchestrator, context builder, policy, tool runner)
- `tools/` (tool implementations)
- `policies/` (tool allow/deny rules, confirmation rules)
- `prompts/` (prompt templates if not fully DB-backed)

Keep existing LLM provider infra under `app/services/llm_providers/` and `app/services/ai/`.

### Data model (persistence + audit)

Add new tables (names shown as suggestion):

- `assistant_threads`: `user_id`, `title`, `status`, `last_activity_at`
- `assistant_messages`: `thread_id`, `role` (user/assistant/tool), `content`, `metadata(json)`
- `assistant_tool_executions`: `thread_id`, `assistant_message_id`, `tool_key`, `args(json)`, `result(json)`, `status`, `started_at`, `finished_at`, `error`, `requires_confirmation`, `approved_at`, `approved_by`
- `assistant_turns` (optional but recommended): `thread_id`, `user_message_id`, `assistant_message_id`, `trace_id`, `context_snapshot(json)`, `llm_api_log_id`, `status`, latency fields

Extend `Ai::LlmApiLog.OPERATION_TYPES` to include `assistant_chat` and `assistant_tool_call` (or store tool calls separately but still reference `llm_api_log_id` for the LLM step).

### Assistant runtime (LLM + tool calling)

Implement an orchestrator (conceptually `Assistant::Chat::Orchestrator`) with strict phases:

1. **Ingest** user message + optional page context (job_listing_id, interview_application_id, opportunity_id).
2. **Build context pack** (token-bounded):

- skill profile summary, fit assessments, active interviews/applications, relevant job listing/opportunity details.

3. **Policy layer** decides allowed tools (read-only vs write tools) for this request.
4. **LLM call** (via existing providers + fallback) with:

- system prompt (DB-managed via `Ai::LlmPrompt` STI, add `Ai::AssistantSystemPrompt`)
- tool schema list (from `assistant_tools` registry)

5. LLM returns either:

- direct answer, or
- **tool proposal**: structured tool calls.

6. For write tools: return a **proposed action plan** requiring user confirmation.
7. On confirmation: execute tool(s) through a **ToolRunner** and post tool results back into the thread.

### Tool system (internal registry + implementations)

**Registry (admin-managed metadata):**

- Model: `AssistantTool` with `tool_key`, `name`, `description`, `enabled`, `risk_level`, `requires_confirmation`, `arg_schema`, `timeout_ms`, `rate_limit`.

**Implementations (code):**

- `Assistant::Tools::*` classes implementing `call(user:, args:)`.
- Every tool must:
- validate args (schema)
- authorize scope to the user
- return structured result `{ success:, data:, error:, side_effects: }`

**Initial tool set (ship read-first):**

- Read-only:
- `get_profile_summary`
- `list_interview_applications`
- `get_interview_application`
- `get_job_listing`
- `get_fit_assessment`
- Write (behind confirmation):
- `add_note_to_application`
- `create_interview_round`
- `save_job_from_url`
- `restore_opportunity`

### Observability (end-to-end)

Add a per-turn **`trace_id`** and propagate through:

- `assistant_turns.trace_id`
- `assistant_tool_executions.trace_id`
- `Ai::LlmApiLog.request_payload` metadata

Capture:

- context snapshot (redacted)
- prompt + model + tokens + cost (already in `Ai::LlmApiLog`)
- tool proposals (even if rejected)
- tool execution status/latency/errors
- confirmation decisions (who approved)

Provide admin dashboards:

- error rates by tool
- tool latency p50/p95
- LLM cost by user/thread/day
- success rate by provider/model

### Resilience + safety

- **Two-phase commit** for write tools (propose → confirm → execute).
- **Idempotency keys** for write tools (avoid double actions on retries).
- **Timeouts** per tool and per LLM call; provider fallback on timeouts/rate limits.
- **Rate limiting** per user for assistant requests and per tool.
- **Prompt injection defenses**: treat job descriptions/emails as untrusted; enforce server-side tool validation.
- **Background jobs** for long tools (scraping, heavy analysis) with tool execution status updates posted back to chat.

### UI (Turbo Streams hybrid)

- Floating widget:
- loads last active thread or starts new thread
- sends messages via Turbo Streams
- shows proposed actions with Confirm/Cancel
- Dedicated pages:
- `AssistantThreadsController#index` (thread list)
- `AssistantThreadsController#show` (thread detail)
- message composer partial + streaming updates

### Custom Admin (manage + operate)

Create an `Admin::Assistant` section under your existing custom admin:

- `Admin::Assistant::ThreadsController` (search, inspect)
- `Admin::Assistant::TurnsController` (trace view)
- `Admin::Assistant::ToolExecutionsController` (filter, replay, mark resolved)
- `Admin::Assistant::ToolsController` (enable/disable, edit schema/policy)
- `Admin::Ai::LlmPromptsController` already exists; extend with assistant prompt types

Include “ops actions”:

- disable a tool globally
- disable tool for a user
- replay a tool execution (admin-only)
- replay an assistant turn (dev/admin)

### Key files to touch

- New assistant domain: `app/domains/assistant/**`
- Existing logging: [`app/services/ai/api_logger_service.rb`](app/services/ai/api_logger_service.rb) and [`app/models/ai/llm_api_log.rb`](app/models/ai/llm_api_log.rb)
- Existing LLM providers: [`app/services/llm_providers/*`](app/services/llm_providers)
- Existing admin base: [`app/controllers/admin/base_controller.rb`](app/controllers/admin/base_controller.rb)
```1:146:./app/services/ai_assistant_service.rb
# Current assistant is keyword-routed; will be superseded by orchestrator.
class AiAssistantService
  def answer
    case @question
    when /summarize.*interview/ then summarize_interviews
    # ...
    else default_response
    end
  end
end
```




### Test strategy

- Unit tests:
- context builder returns bounded payload
- tool schema validation
- authorization checks for tools