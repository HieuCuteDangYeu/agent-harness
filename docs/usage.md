# How to use agent-harness

Use this after [First-time setup](first-time-setup.md).

## Start

```bash
cd ~/Projects/my-project
agent-harness memory start
agent-harness chatgpt-web open   # only for ChatGPT Web models
codex
```

Ponytail and agentmemory load through the configured host. You do not run them manually for each task.

## Normal workflow

Just describe the work:

```text
Implement this using the repository orchestrator.
Verify it and do not push or merge remotely.
```

`AGENTS.md` routes the request to `.agents/skills/repository-orchestrator/SKILL.md`.

The harness handles:

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

You do not create plan JSON, worktrees, branches, or agents yourself. Existing local changes are included in the temporary baseline automatically.

Codex work uses the host's built-in subagent tools. The harness never launches nested `codex exec` workers. `agy` is used only when the plan assigns Antigravity work.

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

`NO_SKILL_CHANGE` is the normal result. Otherwise only the necessary `.agents/skills/` files are updated.

## Inspect orchestration

Normally the orchestrator handles the helper commands. For troubleshooting:

```bash
agent-harness orchestrate status latest
agent-harness doctor .
agent-harness memory status
agent-harness chatgpt-web status
```

Run state and shadow repositories live under the system temporary directory by default, not inside your project's `.git` directory.

For helper details:

```bash
agent-harness orchestrate --help
```
