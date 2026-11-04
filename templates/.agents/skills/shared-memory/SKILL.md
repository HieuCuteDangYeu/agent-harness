---
name: shared-memory
description: Compatibility guidance for selective agentmemory use. Current repository evidence remains authoritative.
---

# Shared Memory Compatibility Shim

Use agentmemory only when previous engineering decisions, failures, and accepted
outcomes materially help the task. It is optional and not tied to any
particular parent agent. Use the current agent's supported MCP integration,
if configured; do not assume every CLI has agentmemory installed.

Authority remains: explicit task > code/tests > AGENTS.md / repository skills
> verified history > external research.

Retrieve narrowly, skip trivial changes, and save only concise, verified,
durable decisions. Never store secrets, tokens, raw transcripts, or logs.

Orca owns task/worktree/session orchestration and quotas. agentmemory is
advisory history only, not another source of task ownership.
