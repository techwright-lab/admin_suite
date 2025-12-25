# Adding Assistant Tools (Developer Guide)

This guide explains how to implement a new assistant tool, register it in the tool registry, and validate it end-to-end.

## What is a “tool”?

A tool is a server-side action the assistant can propose. Tools are:

- **Registered in DB** (`assistant_tools`) so they can be enabled/disabled and validated.
- **Implemented in Ruby** under `app/domains/assistant/tools/`.
- **Executed through** `Assistant::Tools::Runner` (guardrails live here).

## 1) Decide: read-only vs write tool

Use:

- `risk_level: read_only` for queries that do not change state.
- `risk_level: write_low/write_high` for state changes.
- Set `requires_confirmation: true` for any write tool (two-phase commit).

## 2) Implement the Ruby class

Location: `app/domains/assistant/tools/<tool_name>_tool.rb`

Example skeleton:

```ruby
module Assistant
  module Tools
    class MyTool < BaseTool
      def call(args:, tool_execution:)
        # authorize via user-scoped queries
        # validate args via schema (Runner does this before calling)
        { success: true, data: { ... } }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end
end
```

Conventions:

- Always scope reads/writes to `user` (from `BaseTool`).
- Return a **structured hash**:
  - `success: true/false`
  - `data: {}` on success
  - `error: "..."` on failure

## 3) Define `arg_schema`

Tools are validated against the schema stored in `assistant_tools.arg_schema`.

Supported schema features (today) are intentionally small and dependency-free:

- `type`
- `required`
- `properties`

Keep schemas strict enough to prevent ambiguous tool calls.

## 4) Register (or update) the tool in the registry

Preferred approach: **migration with `upsert_all`** so environments stay consistent.

Example (see `db/migrate/*seed_assistant_toolset*.rb`):

- `tool_key`: stable identifier (used in LLM tool calls)
- `executor_class`: constant name, e.g. `Assistant::Tools::MyTool`
- `timeout_ms`
- `risk_level` / `requires_confirmation`

## 5) Verify tool is allowed

Tool allowlisting currently comes from `Assistant::ToolPolicy` which returns enabled registry tools.

If you later add per-user disables or feature flags, update `ToolPolicy`.

## 6) Smoke test (recommended workflow)

Create a proposed execution and run it:

1. Create `Assistant::ToolExecution` (`status: proposed`)
2. Run `AssistantToolExecutionJob.perform_now(tool_execution.id)`
3. Verify:
   - status transitions (`queued/running/success/error`)
   - `result` / `error`
   - `Assistant::Ops::Event` entries

## 7) UX integration (propose/confirm)

- Read-only tools can be auto-enqueued.
- Write tools must remain `proposed` until user approval.
- The assistant UI displays tool proposals and exposes “Approve/Execute”.

## Common pitfalls

- **Zeitwerk**: tool classes must autoload. Ensure `config/initializers/assistant_domain.rb` is correct.
- **Authorization**: never trust IDs from args unless scoped to `user`.
- **Arg schema drift**: keep `arg_schema` updated when tool args change.
- **Timeouts**: set realistic `timeout_ms` and make tool work fast; for slow work, enqueue a dedicated job and return a status handle.

