# Architecture

`agent-harness` separates planning from execution.

```text
You
 ↓
ChatGPT Web orchestrator
 ↓
internal task graph
 ↓
detached agent-harness dispatcher
 ├─ Codex worktrees
 └─ Gemini worktrees
 ↓
deterministic verification
 ↓
skill-maintenance
 ↓
final review
 ↓
local integration branch
```

## Orchestrator

The orchestrator reads the request, repository, `AGENTS.md`, relevant skills, and selective memory. It creates the smallest useful task graph.

It does not directly spawn native sub-agents for repository execution. It starts the dispatcher and polls durable state under `.git/agent-harness/`.

This prevents bounded ChatGPT/Codex command waits from causing duplicate fallback implementations while agents are still running.

## Dispatcher

The dispatcher:

- validates the graph before execution
- runs detached from the orchestrator command call
- creates isolated worktrees
- schedules dependencies and safe parallel work
- launches Codex/Gemini
- runs verification outside agent self-reports
- integrates successful commits
- runs skill maintenance after implementation
- blocks failed dependents and merge conflicts
- runs final review
- stores status, logs, and summaries under `.git/agent-harness/`

It never pushes or merges remotely by itself.

## Runtime integrations

**Ponytail** provides minimal-change/YAGNI guidance through coding hosts.

**agentmemory** provides selective shared local history. Current code and task requirements always override memory.

**Codex Web GPT** lets a ChatGPT Web model use the local Codex tool surface. Keep its launcher open while using Web models.

## Repository skills

`.agents/skills/` stores durable project-specific knowledge. `skill-maintenance` updates it only when stable architecture, security, persistence, messaging, operational, or domain rules change.

## Authority

```text
explicit task requirements
    > current code/tests
    > AGENTS.md + repository skills
    > agentmemory
    > general research
```

## Safety

- never store secrets in memory or task packets
- executors must not recursively create more agents
- the orchestrator must not duplicate an active dispatcher task
- simplicity must not remove auth, validation, transactions, idempotency, concurrency, data integrity, security, or accessibility controls
- skill maintenance changes only repository skill knowledge
- remote push/merge stays under user control
