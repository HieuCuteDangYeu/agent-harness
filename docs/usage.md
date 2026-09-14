# How to use agent-harness

Use this after [First-time setup](first-time-setup.md).

## Start

```bash
cd ~/Projects/my-project
agent-harness memory start
agent-harness agy start           # only when using Antigravity
agent-harness chatgpt-web open    # only for ChatGPT Web models
codex
```

Ponytail and agentmemory load through the configured host. You do not run them manually for each task.

## Normal workflow

Just describe the work:

```text
Implement this using the repository orchestrator.
Verify it and do not push or merge remotely.
```

`AGENTS.md` routes this to `.agents/skills/repository-orchestrator/SKILL.md`.

```text
your current worktree
   ↓
temporary shadow repository
   ↓
Codex native subagents + optional Antigravity (`agy`)
   ↓
deterministic verification
   ↓
skill-maintenance
   ↓
final review
   ↓
verified patch applied back to your worktree
```

Codex tasks use native subagents. Antigravity tasks use the host-side runner started from your normal terminal, so `agy` keeps its normal authentication, language server, localhost sockets, and device access instead of inheriting the Codex/Web sandbox.

There is no silent fallback between Codex and `agy`. The executor selected by the plan owns that task.

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

## Antigravity runner

Check the host runner:

```bash
agent-harness agy status
```

Live smoke test:

```bash
agent-harness agy doctor
```

If it is stopped, run this from a normal terminal, not from inside the Web/Codex orchestrator:

```bash
agent-harness agy start
```

The host runner accepts only disposable task/review worktrees created under the harness state directory. It rejects arbitrary project, home-directory, or other host paths before starting `agy`.

By default the runner does not allow Antigravity's unrestricted `--dangerously-skip-permissions` mode. If a trusted task genuinely needs host commands that headless request-review cannot approve, such as ADB, opt in explicitly from your normal terminal:

```bash
AGENT_HARNESS_AGY_ALLOW_YOLO=1 agent-harness agy restart
```

This gives `agy` unrestricted host command permissions for assigned isolated worktrees, so enable it only when you accept that risk. Restart normally without the environment variable to disable it again.

If a Web tool window expires while an `agy` task is still running, repeat the same orchestration command. The job is idempotent and continues in the host runner rather than spawning a duplicate worker.

## Skill maintenance

After substantial implementation, `skill-maintenance` checks whether durable repository knowledge changed.

`NO_SKILL_CHANGE` is the normal result. Otherwise only the necessary `.agents/skills/` files are updated.

## Inspect orchestration

```bash
agent-harness orchestrate status latest
agent-harness doctor .
agent-harness memory status
agent-harness agy status
agent-harness chatgpt-web status
```

Run state and shadow repositories live under the system temporary directory by default, not inside your project's `.git` directory.

For helper details:

```bash
agent-harness orchestrate --help
```
