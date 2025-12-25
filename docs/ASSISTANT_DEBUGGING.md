# Assistant Debugging & Ops Playbook

This playbook is for investigating assistant issues (wrong answers, missing tool proposals, failed tool executions, unexpected duplicates).

## Quick map: where to look

- **User chat UI**
  - `/assistant` and `/assistant/threads/:uuid`
- **Admin ops**
  - `/admin/assistant_threads`
  - `/admin/assistant_turns`
  - `/admin/assistant_tool_executions`
  - `/admin/assistant_events`
- **LLM logs**
  - `/admin/ai/llm_api_logs`

## Primary correlation identifiers

Use these in this order:

1. **trace_id**: best for end-to-end correlation of a single turn/tool run.
2. **thread.uuid**: stable identifier for the conversation.
3. **turn.uuid / tool_execution.uuid**: stable identifiers for a single record.
4. **turn.client_request_uuid**: used to detect/replay client retries and prevent duplicates.

## Common investigations

### 1) “The assistant answered but tool proposals didn’t appear”

Check:

- The LLM output metadata on the assistant message (`Assistant::ChatMessage.metadata["tool_calls"]`).
- Whether tool executions were created (`Assistant::ToolExecution` rows for the thread).
- Whether tools are enabled in registry (`assistant_tools.enabled = true`).
- Whether tool keys returned by the model match `assistant_tools.tool_key`.

Likely causes:

- Tool disabled in registry
- LLM returned malformed JSON (parser fallback created a plain text answer)
- Tool keys don’t match registry keys

### 2) “Tool execution is stuck in proposed/queued/running”

Check:

- `Assistant::ToolExecution.status`
- Background jobs dashboard (`/internal/jobs`)
- `Assistant::Ops::Event` entries for the tool execution trace

Likely causes:

- Confirmation required but not approved
- Job queue issue / worker not running
- Tool timeout or exception (see `error`)

### 3) “Tool says Invalid executor_class”

Check the tool registry row:

- `assistant_tools.executor_class` must match the Ruby constant and autoload correctly.
- Ensure Zeitwerk config supports tool loading (`config/initializers/assistant_domain.rb`).

### 4) “Duplicate messages / double responses”

Chat send idempotency:

- `assistant_turns.client_request_uuid` is unique per thread.
- If duplicates exist, inspect whether a send path bypassed `client_request_uuid` (e.g., older client or API caller).

Tool replay idempotency:

- Admin replay uses `assistant_tool_executions.replay_of_id` + `replay_request_uuid` to prevent double-replay.

### 5) “Wrong data / unauthorized access concerns”

All tools must scope data to the user. For investigation:

- Verify tool implementations query through `user.*` associations or validate ownership explicitly.
- The tool runner also checks thread ownership.

## Operational actions

- **Disable a tool**: use `/admin/assistant_tools` and toggle enabled.
- **Replay a tool execution**: `/admin/assistant_tool_executions/:id` → Replay.
- **Filter by trace**: thread/turn/execution/event pages support filtering by trace_id.

## Useful SQL snippets (Postgres)

Find everything for a trace:

```sql
SELECT * FROM assistant_turns WHERE trace_id = '<trace>';
SELECT * FROM assistant_tool_executions WHERE trace_id = '<trace>';
SELECT * FROM assistant_events WHERE trace_id = '<trace>' ORDER BY created_at ASC;
```

Find tool failures:

```sql
SELECT tool_key, count(*) AS failures
FROM assistant_tool_executions
WHERE status = 'error'
GROUP BY tool_key
ORDER BY failures DESC;
```

