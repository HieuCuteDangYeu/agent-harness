# How to use agent-harness

Use this after [First-time setup](first-time-setup.md) is complete.

## Start your project

```bash
cd ~/Projects/my-project
agent-harness memory start
agent-harness chatgpt-web open   # only when using ChatGPT Web models
codex
```

`memory start` is safe when memory is already running. Codex Web GPT only needs to stay open while you use a ChatGPT Web model in Codex.

You do not manually run Ponytail for each task. Once installed/trusted, the coding host loads it automatically.

## Normal usage: just describe the task

You do **not** need to create a GitHub issue or a plan JSON first.

For substantial work, tell the ChatGPT Web orchestrator what you want:

```text
Improve the reel recommendation system.
Use the repository orchestrator and implement it.
Do not push or merge remotely.
```

The orchestrator should automatically:

```text
your request
    ↓
inspect repo + AGENTS.md + relevant skills
    ↓
selectively recall memory when useful
    ↓
create internal task graph
    ↓
generate plan JSON internally
    ↓
agent-harness orchestrate
    ↓
Codex / Gemini worktrees
    ↓
deterministic verification
    ↓
final review
    ↓
local integration branch
```

The JSON plan is an internal handoff format. In normal use you should never need to write it yourself.

## Do I need a GitHub issue?

No.

The active task can come directly from your request plus the current repository. If you provide an existing issue or PR, the orchestrator should use it as authoritative task evidence.

Create an issue when you want a durable remote record, team coordination, or cross-session traceability. The harness should not create one automatically just because GitHub is used by the project.

Examples:

```text
Implement GitHub issue #142 using the repository orchestrator.
```

or simply:

```text
Fix reset-token replay in auth-service using the repository orchestrator.
```

Both are valid.

## Plan only

If you want to review the plan before code changes:

```text
Plan the implementation for this task using the repository orchestrator.
Do not execute it yet.
```

The orchestrator should inspect the repository, produce the task graph, and stop.

If you later approve it:

```text
Approved. Execute the plan.
```

The orchestrator should generate the dispatcher plan internally and run it. You still do not need to create JSON yourself.

## Single-agent work

For a small focused task, use Codex directly:

```text
Fix the validation bug in the current endpoint.
Read AGENTS.md and relevant repository skills first.
Use memory only if previous project history materially helps.
Run targeted verification and review the final diff.
```

Use multi-agent orchestration only when decomposition provides real value.

## What automatic execution does

The dispatcher:

- validates the generated task graph before creating branches/worktrees or launching agents
- creates isolated worktrees
- starts dependency-ready tasks in parallel when safe
- launches the assigned `codex` or `gemini` CLI with its installed host configuration
- runs declared verification commands itself
- commits successful uncommitted executor changes
- integrates successful commits into a local `agent/orchestrate-*` branch
- blocks dependents after failed tasks or conflicts
- runs the configured final reviewer
- records evidence under `.git/agent-harness/runs/`
- removes temporary worktrees unless debugging retention is requested

It never pushes or merges remote branches automatically.

Ponytail and agentmemory are host-level integrations, not task nodes. `AGENTS.md` already defines when they should be used.

## Inspect the result

The harness prints the generated integration branch. Useful commands are:

```bash
git branch --list 'agent/orchestrate/*'
git log --oneline <base>..agent/orchestrate/<run-branch>
git diff <base>...agent/orchestrate/<run-branch>
find .git/agent-harness/runs -maxdepth 2 -type f | sort
```

Only push or create a PR after reviewing the local integration branch.

## Failure behavior

```text
failed task
    ↓
dependent tasks blocked
    ↓
independent already-running tasks may still finish
```

Merge conflicts fail the affected task rather than being silently resolved by an LLM. If a configured final reviewer does not return `VERDICT: PASS`, the run is not successful.

## Advanced: manual dispatcher usage

Manual JSON is available for debugging, CI experiments, or users who want direct control over the task graph. It is not the normal workflow.

```bash
agent-harness orchestrate example
agent-harness orchestrate example > /tmp/plan.json
agent-harness orchestrate /tmp/plan.json --dry-run
agent-harness orchestrate /tmp/plan.json
agent-harness orchestrate /tmp/plan.json --keep-worktrees
agent-harness orchestrate /tmp/plan.json --max-parallel 3
```

Default parallelism is 2; the maximum is 8.

## Memory and skills

Authority order:

```text
explicit task requirements
        >
current code/tests
        >
supplied GitHub issue/PR requirements
        >
AGENTS.md + repository skills
        >
agentmemory
        >
general research
```

After verified work, save only durable decisions/root causes/outcomes to memory. Run `skill-maintenance` only when a reusable repository workflow or architectural invariant changed. Never store secrets in memory.

## Command cheat sheet

```bash
# health
agent-harness version
agent-harness doctor .

# ChatGPT Web launcher
agent-harness chatgpt-web status
agent-harness chatgpt-web open
agent-harness chatgpt-web repair

# memory
agent-harness memory status
agent-harness memory start
agent-harness memory stop
agent-harness memory restart
agent-harness memory logs
agent-harness memory viewer
agent-harness memory data-dir
agent-harness memory doctor

# advanced/manual orchestration
agent-harness orchestrate example
agent-harness orchestrate /tmp/plan.json --dry-run
agent-harness orchestrate /tmp/plan.json
```
