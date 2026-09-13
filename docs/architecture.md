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
skill-maintenance
 ↓
final review
 ↓
local integration branch
```

## Orchestrator

The orchestrator reads the request, repository, `AGENTS.md`, relevant skills, and selective memory. It decides the smallest useful task graph and assigns Codex/Gemini work.

The task graph is an internal handoff. Users do not need to write plan JSON.

For substantial execution, the graph ends with a `skill-maintenance` task. It inspects the integrated change and updates `.agents/skills/` only when stable repository knowledge changed. No-op is the normal result for ordinary implementation details.

## Dispatcher

The dispatcher is deterministic. It:

- validates the graph before execution
- creates isolated worktrees
- schedules dependencies and safe parallel work
- launches Codex/Gemini
- runs verification outside the agents' self-reports
- integrates successful commits
- runs skill maintenance after implementation work
- blocks failed dependents and merge conflicts
- runs final review after any skill updates
- writes run state under `.git/agent-harness/`

It never pushes or merges remotely by itself.

## Runtime integrations

**Ponytail** provides minimal-change/YAGNI guidance through Codex, Gemini, and Antigravity host integrations.

**agentmemory** provides shared local history. Recall is selective; current code and task requirements always override memory. Persistent data stays outside project repositories.

**Codex Web GPT** lets a ChatGPT Web model use the local Codex tool surface. Keep its launcher open only while using Web models.

## Repository skills

`.agents/skills/` stores durable project-specific knowledge such as architecture, security rules, persistence conventions, messaging workflows, and domain constraints.

`skill-maintenance` keeps those skills aligned with verified code changes. It should not record one-off fixes, obvious code facts, or generic framework behavior.

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
- skill maintenance may change only repository skill knowledge, not implementation code
- Gemini `yolo` is opt-in; default is `auto_edit`
- reviewer changes are not accepted as implementation
- remote push/merge stays under user control
