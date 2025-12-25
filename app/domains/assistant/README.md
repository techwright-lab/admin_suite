# Assistant Domain

This domain contains the internal **Assistant** layer: chat threads, messages, tool calling, policies, and execution audit/observability.

High-level structure:

- `models/`: ActiveRecord models for assistant persistence (threads, messages, tool executions, turns, tools registry)
- `services/`: Orchestration (context building, LLM calls, tool planning/execution)
- `tools/`: Tool implementations (read + write actions inside Gleania)
- `policies/`: Allow/deny + confirmation policies for tool usage

