# How to use agent-harness

Use this after [First-time setup](first-time-setup.md).

## Start

```bash
cd ~/Projects/my-project
agent-harness memory start
agent-harness chatgpt-web open   # only for ChatGPT Web models
agent-harness orca open
```

Then open the repository in Orca and launch the parent Codex session there. If you use ChatGPT Web through Codex Web GPT, select that Web model for the parent session.

Ponytail and agentmemory load through the coding agents. Orca owns the multi-agent execution surface.

## Normal workflow

Ask naturally:

```text
Implement this using the repository orchestrator.
Verify it and do not push or merge remotely.
```

`AGENTS.md` routes the request to `.agents/skills/repository-orchestrator/SKILL.md`. That repository policy then loads Orca's live `orchestration` guide before creating or mutating a Run.

The intended flow is:

```text
you
 ↓
ChatGPT Web / Codex parent in Orca
 ↓
repository-orchestrator policy
 ↓
Orca live orchestration skill
 ↓
Orca Run
 ├─ Codex worker session(s)
 ├─ Antigravity worker session(s)
 ├─ verification task(s)
 └─ independent review task
 ↓
decision gate
 ↓
review/integrate locally
```

Orca owns worktrees, task dependencies, worker sessions, messages, per-worker model/effort options, and gates. `agent-harness` no longer runs its own orchestration engine or Antigravity host runner.

## Multiple sessions

Use Orca's Run/task model when several agents should collaborate or work independently. Keep task-level concurrency in Orca so the UI remains the single source of truth for which worker owns what.

Codex and Antigravity are first-class Orca agents. The repository policy does not silently swap one executor for another when a worker fails or stalls; use Orca's current recovery/reassignment controls deliberately.

For competing approaches, say so explicitly. Otherwise the orchestrator should split by real ownership/dependency boundaries instead of launching duplicate agents on the same task.

## Model and reasoning effort

Orca supports per-worker model and reasoning-effort overrides. The orchestrator must use the version-matched live Orca guide rather than hard-coding model IDs or effort values.

This means you can request, for example, a fast implementation worker and a stronger reviewer without changing the repository harness.

## Android / ADB work

When `adb` was present during setup, the harness installs Orca's `orca-emulator-android` skill. For Android tasks, the parent/worker should load that live skill and use Orca's adb-connected device or emulator workflow.

Device access still depends on the host/session being able to see the device. Do not treat model choice as a substitute for host permissions.

## Dirty working tree

A new Orca worktree is a clean checkout from a Git ref/commit. Uncommitted changes in another checkout are not automatically inherited.

Before starting a Run that depends on local edits:

```bash
git status --short
```

If those edits matter, commit/snapshot them first or continue from an Orca-managed branch/worktree that already contains them. The repository-orchestrator skill will not silently stash or commit your checkout.

## Small task

For a focused change that does not benefit from multiple sessions, use one Codex or Antigravity session directly:

```text
Fix the validation bug in this endpoint.
Read AGENTS.md and relevant repository skills first.
Run targeted verification and review the diff.
```

You do not need to invoke Orca orchestration for every task.

## Plan only

```text
Plan this with the repository orchestrator.
Do not execute the Orca Run yet.
```

Then:

```text
Approved. Execute the plan in Orca.
```

## Skill maintenance

After substantial implementation, a Run can include `skill-maintenance` before final review when durable repository knowledge may have changed.

`NO_SKILL_CHANGE` is the normal result. Otherwise only the necessary `.agents/skills/` files should change.

## Troubleshooting

```bash
agent-harness orca status
agent-harness orca doctor
agent-harness doctor .
agent-harness memory status
agent-harness chatgpt-web status
```

To inspect the live orchestration protocol Orca currently exposes:

```bash
agent-harness orca guide
```

Do not use old `agent-harness orchestrate ...` commands; that custom runtime was removed when Orca became the orchestration engine.
