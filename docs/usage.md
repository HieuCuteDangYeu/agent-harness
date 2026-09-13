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

For substantial work, just describe the task:

```text
Improve the reel recommendation system using the repository orchestrator.
Implement it, verify it, and do not push or merge remotely.
```

The orchestrator handles the rest:

```text
your request
   ↓
inspect repo + AGENTS.md + relevant skills
   ↓
recall memory only when useful
   ↓
create task graph internally
   ↓
run Codex / Gemini in isolated worktrees
   ↓
run deterministic verification
   ↓
final review
   ↓
local integration branch
```

You do not create the task graph or plan JSON yourself.

## Plan only

If you want to review the approach first:

```text
Plan this task using the repository orchestrator.
Do not execute it yet.
```

Then continue with:

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

Use multi-agent orchestration only when splitting the work is useful.

## What the dispatcher does

It automatically:

- validates the generated task graph
- creates isolated Git worktrees
- runs independent Codex/Gemini tasks in parallel when safe
- waits for dependencies
- runs declared verification commands itself
- integrates successful changes into `agent/orchestrate-*`
- blocks dependent work after failures or conflicts
- runs a final reviewer
- stores logs under `.git/agent-harness/`

It does not push or merge remote branches.

## Inspect the result

The harness prints the integration branch. Common checks:

```bash
git branch --list 'agent/orchestrate/*'
git diff <base>...agent/orchestrate/<run-branch>
git log --oneline <base>..agent/orchestrate/<run-branch>
```

Only push after you review the result.

## Troubleshooting

```bash
agent-harness doctor .
agent-harness memory status
agent-harness memory logs
agent-harness chatgpt-web status
```

If needed:

```bash
agent-harness memory restart
agent-harness chatgpt-web open
```

For dispatcher debugging, run `agent-harness orchestrate --help`.
