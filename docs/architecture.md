# Architecture

`agent-harness` is now a setup and repository-policy layer around Orca rather than a second orchestration runtime.

```text
You
 ↓
ChatGPT Web / Codex parent session in Orca
 ↓
repository-orchestrator policy
 ↓
Orca live orchestration skill
 ↓
Orca Run + worktrees + worker sessions
 ├─ Codex
 ├─ Antigravity (`agy`)
 └─ other Orca-supported agents when explicitly useful
 ↓
verification task(s) + independent review
 ↓
decision gate
 ↓
local review/integration
```

## Why Orca owns orchestration

Orca already provides the primitives this repository previously implemented itself: worktree-native isolation, multiple live agent sessions, Runs/tasks, supervised workers, messages, model/effort overrides, progress/status, and decision gates.

Maintaining a second DAG/worktree/executor layer underneath Orca would create two sources of truth for ownership, retries, Git state, and worker lifecycle. Version 0.8 therefore removes the custom `agent-harness orchestrate` runtime and the custom host-side Antigravity runner.

## Parent orchestrator

The parent session may be normal Codex or a ChatGPT Web model reached through Codex Web GPT.

`AGENTS.md` routes explicit multi-agent requests to `.agents/skills/repository-orchestrator/SKILL.md`. That local skill contains repository policy only. Before it mutates a Run it loads Orca's version-matched live `orchestration` guide.

This keeps command syntax owned by Orca while preserving our durable rules around repository context, verification, review, scope, and remote-operation safety.

## Orca execution plane

Orca owns:

- Run/task graph state
- Git worktree creation and lifecycle
- worker sessions and status
- Codex and Antigravity launches
- worker messages/recovery controls
- per-worker model and reasoning-effort options
- decision gates
- diff/review surfaces

The harness does not start sibling implementation workers outside Orca during an active Run.

## Repository-policy layer

The harness still owns or installs:

- `AGENTS.md`
- repository-specific `.agents/skills/`
- `repository-orchestrator` policy wrapper
- `repo-skill-bootstrap`
- `skill-discovery`
- `skill-maintenance`
- `shared-memory`
- Ponytail setup
- agentmemory setup/service helpers
- Codex Web GPT setup/control
- Orca CLI/skill discovery helpers

This is deliberately smaller than the old orchestration engine.

## Orca skill integration

The harness resolves Orca using `ORCA_CLI_COMMAND`, `orca-dev`, Linux `orca-ide`, then `orca`.

`agent-harness orca setup` installs Orca's `orca-cli` and `orchestration` skills through Orca's own CLI. When `adb` is available it also installs `orca-emulator-android`.

Agents should use:

```bash
agent-harness orca guide
```

before changing orchestration state. This delegates command/version compatibility to Orca rather than freezing Orca CLI flags inside this repository.

## Codex Web GPT

Codex Web GPT remains optional parent transport only:

```text
ChatGPT Web model
      ↓
Codex Web GPT bridge
      ↓
parent Codex session inside Orca
      ↓
Orca orchestration
```

It is never a repository worker.

## Antigravity

Antigravity is launched directly by Orca as a supported agent. The custom `agent-harness` host runner is gone.

This is simpler because Orca already owns the agent process, worktree cwd, session status, and UI. For Android work, Orca's Android skill can use adb-connected devices/emulators when the host has access.

## Dirty checkout boundary

Orca worktrees start from Git refs or commits and are clean checkouts. They do not automatically snapshot uncommitted changes from another checkout.

That differs from the old harness shadow-repository behavior. The repository-orchestrator policy therefore checks for relevant dirty state before creating a Run and fails closed rather than assuming workers can see it.

If current edits matter, the user should commit/snapshot them or orchestrate from an Orca-managed branch/worktree containing those changes.

## Verification and review

Orca's flexibility does not weaken the repository contract. For substantial changes, the task graph should include explicit verification and an independent review followed by a decision gate.

A worker saying "tests pass" is not enough when the plan requires evidence. The orchestrator should capture actual command/test results in the appropriate Orca task/session and block the gate on failures.

## Shared memory and skills

**agentmemory** remains selective historical context. Current code and task requirements always override it.

**Ponytail** remains minimal-change/YAGNI guidance for supported coding agents.

**Repository skills** remain the durable source for project-specific architecture, security, persistence, messaging, operational, and domain procedures.

## Authority

```text
explicit task requirements
    > current code/tests
    > AGENTS.md + repository skills
    > agentmemory
    > general research
```

## Safety

- review Orca agent permission defaults before autonomous runs
- never store secrets in memory or task packets
- do not create duplicate sibling workers outside Orca for an active Run
- do not assume uncommitted caller changes are present in new Orca worktrees
- keep verification and final review explicit for substantial work
- remote push/merge stays under user control unless explicitly authorized
- simplicity must not remove auth, validation, transactions, idempotency, concurrency, data integrity, security, error handling, or accessibility controls
