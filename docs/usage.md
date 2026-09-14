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

`AGENTS.md` routes an explicit orchestrator request to the `repository-orchestrator` skill under `.agents/skills/`; native Codex/ChatGPT agent delegation is not used for that flow.

The orchestrator handles the rest:

```text
your request
   ↓
inspect repo + relevant skills/memory
   ↓
create task graph internally
   ↓
start detached dispatcher
   ↓
Codex / Gemini worktrees
   ↓
verification
   ↓
skill-maintenance
   ↓
final review
   ↓
local integration branch
```

You do not create plan JSON, worktrees, or agents yourself.

The dispatcher runs detached so ChatGPT/Codex command wait limits do not interrupt it. The orchestrator checks durable run state instead of starting duplicate fallback work.

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

The integration branch is `agent/orchestrate-*`. The dispatcher never pushes or merges remotely.

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
