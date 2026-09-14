# Architecture

`agent-harness` separates orchestration, execution, and verification.

```text
You
 ↓
ChatGPT Web / Codex orchestrator
 ↓
repository-orchestrator skill
 ↓
internal task graph
 ↓
shadow repository + isolated worktrees
 ├─ Codex native subagents
 └─ Antigravity (`agy`) workers
 ↓
deterministic verification + integration
 ↓
skill-maintenance
 ↓
final review
 ↓
verified patch applied to caller worktree
```

## Orchestrator

`AGENTS.md` routes explicit orchestration requests to `.agents/skills/repository-orchestrator/SKILL.md`.

The parent orchestrator inspects the task, code, tests, relevant skills, and selective memory, then builds the smallest useful dependency graph.

Codex tasks use Codex's built-in subagent tools. The harness does not launch nested `codex exec` processes.

## Harness helper

`agent-harness orchestrate` is a deterministic Git/worktree helper, not another agent runtime.

It:

- snapshots the caller's committed, modified, deleted, and untracked non-ignored files into a temporary shadow repository
- creates one isolated worktree per task
- prints the exact task packet for native Codex subagents
- launches `agy` only for Antigravity-assigned tasks
- runs declared verification commands itself
- commits and integrates successful task worktrees
- blocks dependents after failures or merge conflicts
- creates a disposable final-review worktree
- applies only the verified delta back to the caller worktree
- never pushes or merges remotely

The caller repository's `.git` directory is not used for orchestration branches or run state.

## Codex native subagents

Native Codex subagents are the Codex execution primitive. They inherit the parent host/session instead of starting another Codex CLI runtime.

Each subagent receives an absolute temporary worktree path and must work only there. The parent uses native wait/message/close tools to manage its lifecycle, while the harness helper verifies and integrates the result afterward.

This avoids nested Codex runtime state, SQLite, AppImage, and sandbox compatibility workarounds.

## Antigravity

Antigravity remains an external executor through `agy`. It is useful for independent UI-oriented work, focused tests, or secondary implementation/review.

If `agy` is not installed, the orchestrator simply avoids assigning Antigravity tasks.

## Runtime integrations

**Ponytail** provides minimal-change/YAGNI guidance through the coding hosts.

**agentmemory** provides selective shared local history. Current code and task requirements always override memory.

**Codex Web GPT** is only the parent bridge that lets a ChatGPT Web model use the local Codex tool surface. It is never a repository worker.

## Repository skills

`.agents/skills/` stores task workflows and durable project-specific knowledge.

`repository-orchestrator` defines the execution protocol. `skill-maintenance` keeps repository-specific skills aligned only when stable architecture, security, persistence, messaging, operational, or domain rules change.

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
- task subagents must not recursively delegate
- never run the same implementation task in two places at once
- verification is executed by the harness helper, not trusted from agent self-reports
- remote push/merge stays under user control
- simplicity must not remove auth, validation, transactions, idempotency, concurrency, data integrity, security, or accessibility controls
