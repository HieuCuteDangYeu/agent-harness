# Architecture

`agent-harness` separates planning from execution.

```text
You
 ↓
ChatGPT Web orchestrator
 ↓
internal task graph
 ↓
agent-harness orchestrate
 ├─ Codex worktrees
 └─ Gemini worktrees
 ↓
deterministic verification
 ↓
final review
 ↓
local integration branch
```

## Orchestrator

The orchestrator reads the request, repository, `AGENTS.md`, relevant skills, and selective memory. It decides the smallest useful task graph and assigns Codex/Gemini work.

The task graph is an internal handoff. Users do not need to write plan JSON.

## Dispatcher

The dispatcher is deterministic. It:

- validates the graph before execution
- creates isolated worktrees
- schedules dependencies and safe parallel work
- launches Codex/Gemini
- runs verification outside the agents' self-reports
- integrates successful commits
- blocks failed dependents and merge conflicts
- runs final review
- writes run state under `.git/agent-harness/`

It never pushes or merges remotely by itself.

## Runtime integrations

**Ponytail** provides minimal-change/YAGNI guidance through Codex, Gemini, and Antigravity host integrations.

**agentmemory** provides shared local history. Recall is selective; current code and task requirements always override memory. Persistent data stays outside project repositories.

**Codex Web GPT** lets a ChatGPT Web model use the local Codex tool surface. Keep its launcher open only while using Web models.

## Authority

```text
explicit task requirements
    > current code/tests
    > AGENTS.md + repository skills
    > agentmemory
    > general research
```

Git/GitHub remains the durable code, review, CI, and history layer. The harness does not require any separate remote task record before work starts.

## Safety

- never store secrets in memory or task packets
- simplicity must not remove auth, validation, transactions, idempotency, concurrency, data integrity, security, or accessibility controls
- Gemini `yolo` is opt-in; default is `auto_edit`
- reviewer changes are not accepted as implementation
- remote push/merge stays under user control
