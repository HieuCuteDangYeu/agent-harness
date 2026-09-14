# Architecture

`agent-harness` separates planning from execution.

```text
You
 ↓
ChatGPT Web orchestrator
 ↓
repository-orchestrator skill
 ↓
internal task graph
 ↓
detached dispatcher
 ↓
shadow repo from current worktree
 ├─ Codex workers
 └─ Antigravity (`agy`) workers
 ↓
deterministic verification
 ↓
skill-maintenance
 ↓
final review
 ↓
verified patch applied to caller worktree
```

## Orchestrator

`AGENTS.md` is the routing layer. When orchestration is requested, it activates `.agents/skills/repository-orchestrator/SKILL.md`.

The skill reads the request, repository, relevant skills, and selective memory, then creates the smallest useful task graph. It never uses native sub-agent delegation for repository execution.

## Dispatcher

Detached execution snapshots the caller's current committed, modified, deleted, and untracked non-ignored files into a temporary Git repository. All branches, commits, worktrees, and run metadata are created there, so normal orchestration does not need to write the caller repository's `.git` directory.

The dispatcher:

- validates the graph before execution
- preserves an existing dirty caller worktree as the baseline
- creates isolated task worktrees in the shadow repository
- schedules dependencies and safe parallel work
- uses Codex and Antigravity (`agy`) directly, with fallback to the other installed executor when needed
- runs verification outside agent self-reports
- integrates successful commits
- runs skill maintenance after implementation
- blocks failed dependents and merge conflicts
- runs final review
- applies only the verified result delta back to the caller worktree
- stores status, logs, patch, and shadow repository under the system temporary directory by default

It never pushes or merges remotely by itself.

## Runtime integrations

**Ponytail** provides minimal-change/YAGNI guidance through coding hosts.

**agentmemory** provides selective shared local history. Current code and task requirements always override memory.

**Codex Web GPT** lets a ChatGPT Web model use the local Codex tool surface. Keep its launcher open while using Web models.

## Repository skills

`.agents/skills/` stores task workflows and durable project-specific knowledge.

`repository-orchestrator` is the harness execution workflow. `skill-maintenance` keeps repository-specific skills aligned only when stable architecture, security, persistence, messaging, operational, or domain rules change.

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
- verified patches are checked before they are applied back to the caller worktree
- simplicity must not remove auth, validation, transactions, idempotency, concurrency, data integrity, security, or accessibility controls
- skill maintenance changes only repository skill knowledge
- remote push/merge stays under user control
