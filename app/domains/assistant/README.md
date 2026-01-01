# Assistant Domain

This domain contains the internal **Assistant** layer: chat threads, messages, tool calling, policies, and execution audit/observability.

High-level structure:

- `models/`: ActiveRecord models for assistant persistence (threads, messages, tool executions, turns, tools registry)
- `services/`: Orchestration (context building, LLM calls, tool planning/execution)
- `tools/`: Tool implementations (read + write actions inside Gleania)
- `policies/`: Allow/deny + confirmation policies for tool usage

## Contracts + boundaries (recommended)

The assistant stack integrates multiple LLM providers and native tool calling. To keep this maintainable as it grows:

- **Single owner of the workflow**: `Assistant::Chat::TurnRunner` should be the only place that owns the turn lifecycle (LLM call → persist turn → propose tools → enqueue tools → follow-up). Jobs/controllers should delegate to it.
- **Provider adapters are translators**: `LlmProviders::*Provider` should only build provider requests and parse provider responses into a provider-agnostic shape. Avoid UX decisions (placeholders, confirmations) in adapters.
- **Add contracts at seams**: validate the shapes of provider outputs and internal tool protocol objects, instead of letting `Hash`-y data flow deep into the system.

### Contract options

- **Dry::Schema / dry-validation** (recommended): strict runtime validation at boundaries (provider parsing → internal protocol).
- **Typed structs (optional)**: `dry-struct` / `dry-types` or (separately) RBS/Sorbet for extra safety.

### What to validate first (highest ROI)

- **Tool calls**: every tool call must have a stable `provider_tool_call_id` (OpenAI `call_id`, Anthropic `tool_use_id`) and `args` must be an object.
- **Tool results**: every tool result must include the same `provider_tool_call_id` so follow-ups can reliably pair outputs.
- **Provider state**: for OpenAI, persist the latest `response_id` after follow-ups; avoid using stale `response_id` that is awaiting tool outputs.

