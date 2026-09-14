# How to use agent-harness

Use this after [First-time setup](first-time-setup.md).

## Start

```bash
cd ~/Projects/my-project
agent-harness memory start
agent-harness chatgpt-web open   # only for ChatGPT Web models
codex
```

Ponytail and agentmemory load through the configured coding host. You do not run them manually for each task.

## Normal workflow

Just describe the task:

```text
Improve the reel recommendation system using the repository orchestrator.
Implement it, verify it, and do not push or merge remotely.
```

`AGENTS.md` routes this to `.agents/skills/repository-orchestrator/SKILL.md`.

The harness handles the rest:

```text
your current worktree
   ↓
isolated temporary baseline
   ↓
Codex / Antigravity (agy) workers
   ↓
verification
   ↓
skill-maintenance
   ↓
final review
   ↓
verified patch applied back to your worktree
```

You do not create plan JSON, worktrees, or agents yourself. Existing local changes are preserved automatically; a clean working tree is not required for normal detached orchestration.

The dispatcher uses `codex` and `agy` as first-class executors. If one is unavailable, it can fall back to the other.

The dispatcher runs detached, so a ChatGPT Web disconnect or command wait limit does not cancel the run.

## Plan only

```text
Plan this task using the repository orchestrator.
Do not execute it yet.
```

Then:

```text
Approved. Execute the plan.
```

## Small task

For a focused change, use Codex directly:

```text
Fix the validation bug in this endpoint.
Read AGENTS.md and relevant repository skills first.
Run targeted verification and review the diff.
```

## Skill maintenance

After substantial implementation, `skill-maintenance` checks whether durable repository knowledge changed.

`NO_SKILL_CHANGE` is the normal no-op. Otherwise it updates only the required `.agents/skills/` files.

## Inspect or debug orchestration

Normally ChatGPT handles these commands internally:

```bash
agent-harness orchestrate status latest
agent-harness orchestrate logs latest
```

Detached runtime state and the shadow Git repository live under the system temporary directory by default, not under your project's `.git` directory. The harness never pushes or merges remotely.

## Troubleshooting

```bash
agent-harness doctor .
agent-harness memory status
agent-harness chatgpt-web status
agent-harness orchestrate status latest
```

For advanced dispatcher usage:

```bash
agent-harness orchestrate --help
```
