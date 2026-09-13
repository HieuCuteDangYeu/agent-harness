# How to use agent-harness

Use this after [First-time setup](first-time-setup.md) is complete.

## 1. Start your project

```bash
cd ~/Projects/my-project
agent-harness memory start
agent-harness chatgpt-web open   # only when using ChatGPT Web models
codex
```

`memory start` is safe when memory is already running. Codex Web GPT only needs to stay open while you use a ChatGPT Web model in Codex.

You normally do **not** run Ponytail manually. Once installed/trusted, Codex/Gemini/Antigravity load their Ponytail integration when they start.

## 2. Choose the right mode

### Single-agent task

Use Codex directly for small, focused work:

```text
Implement GitHub issue #142.

Read AGENTS.md and relevant repository skills first.
Use agentmemory only if previous project history materially helps.
Treat the issue acceptance criteria as the contract.
Run the required verification and review the final diff.
```

You do not need to add `use Ponytail` to every prompt. `AGENTS.md` already tells the agent to follow Ponytail when available.

### Plan only

Ask the ChatGPT Web orchestrator to plan when you do not want code changed yet:

```text
Plan the implementation for this task.
Read AGENTS.md, docs/agent-orchestrator.md and relevant skills.
Inspect the current code and tests.
Use agentmemory selectively if previous project decisions materially help.
Do not execute the plan.
```

### Automatic multi-agent implementation

For substantial work, ask the ChatGPT Web model to orchestrate it:

```text
Implement this task using the repository orchestrator.

Read AGENTS.md, docs/agent-orchestrator.md and relevant repository skills.
Inspect the current implementation and tests.
Use agentmemory selectively when history matters.

Create the smallest useful task graph.
Use Codex as the primary implementation executor.
Use Gemini only for genuinely independent work, focused tests, UI-oriented work, or independent review.
Do not make both agents implement the same change.

Dry-run the graph first. If valid, execute it automatically.
Run deterministic verification and final review.
Do not push or merge remotely.
Report the integration branch, task results, verification results, reviewer verdict, and remaining risks.
```

The ChatGPT orchestrator should then invoke `agent-harness orchestrate` through Full Harness.

## 3. How Ponytail and agentmemory apply

The runtime plugins/extensions are host-level integrations, not tasks in the JSON plan.

```text
agent-harness orchestrate
        │
        ├── launches codex exec
        │      ├── Ponytail plugin/hooks
        │      └── agentmemory MCP/hooks
        │
        └── launches gemini
               ├── Ponytail extension
               └── agentmemory adapter
```

### Ponytail

Ponytail reinforces minimal/YAGNI implementation behavior inside the coding agent. Once installed and trusted, it applies to:

- interactive Codex sessions
- Codex `exec` processes launched by the dispatcher
- Gemini CLI sessions when the extension is installed
- Antigravity sessions when its plugin is installed

You normally should **not**:

- add a separate orchestration node called `run Ponytail`
- reinstall it before every task
- repeat long Ponytail instructions in every executor prompt

The repository contract already says to use Ponytail when available. Safety/correctness requirements still override simplicity.

### agentmemory

agentmemory provides shared local history through MCP/adapters. Keep the service running:

```bash
agent-harness memory start
```

Agents should recall history only when useful. Typical tools are `memory_smart_search` / `memory_recall`, with `memory_save` / `memory_lesson_save` reserved for concise durable verified lessons.

Broad automatic context injection stays off by default, so a fresh executor does not receive the entire memory store. It can query the same shared memory service when the task warrants it.

## 4. What happens during automatic execution

```text
ChatGPT orchestrator
       │
       ▼
JSON task graph
       │
       ▼
dry-run validation
       │
       ▼
agent-harness orchestrate
       │
 ┌─────┴─────┐
 ▼           ▼
Codex      Gemini
worktree   worktree
 └─────┬─────┘
       ▼
dependency-aware integration
       ▼
deterministic verification
       ▼
final reviewer
       ▼
local integration branch
```

The dispatcher automatically:

- validates task IDs, dependencies and cycles
- creates isolated worktrees
- starts dependency-ready tasks, in parallel when safe
- launches the assigned `codex` or `gemini` CLI using that host's installed plugin/extension configuration
- runs each task's declared verification commands itself
- commits successful uncommitted executor changes
- integrates successful commits into a local `agent/orchestrate-*` branch
- blocks dependent tasks after failures or conflicts
- runs the configured final reviewer
- records logs/status/summary under `.git/agent-harness/runs/`
- cleans temporary worktrees unless `--keep-worktrees` is used

It does **not** automatically push or merge remote branches.

## 5. Manual dispatcher usage

Print the example plan:

```bash
agent-harness orchestrate example
```

Save and validate a plan:

```bash
agent-harness orchestrate example > /tmp/plan.json
agent-harness orchestrate /tmp/plan.json --dry-run
```

Execute it:

```bash
agent-harness orchestrate /tmp/plan.json
```

Keep worktrees for debugging:

```bash
agent-harness orchestrate /tmp/plan.json --keep-worktrees
```

Override concurrency:

```bash
agent-harness orchestrate /tmp/plan.json --max-parallel 3
```

Default parallelism is 2. The maximum is 8.

## 6. Plan shape

A plan is versioned JSON:

```json
{
  "version": 1,
  "name": "example-task",
  "goal": "Implement the requested behavior safely.",
  "base": "HEAD",
  "maxParallel": 2,
  "tasks": [
    {
      "id": "backend",
      "agent": "codex",
      "prompt": "Implement the backend behavior.",
      "dependsOn": [],
      "acceptanceCriteria": [
        "Required behavior works",
        "Existing contracts remain compatible"
      ],
      "verify": [
        "pnpm test --filter backend"
      ]
    },
    {
      "id": "tests",
      "agent": "gemini",
      "prompt": "Add focused regression tests for the integrated backend behavior.",
      "dependsOn": ["backend"],
      "acceptanceCriteria": [
        "Important success and failure paths are covered"
      ],
      "verify": [
        "pnpm test --filter backend"
      ]
    }
  ],
  "review": {
    "agent": "codex",
    "prompt": "Check correctness, architecture, security, compatibility and missing tests."
  }
}
```

Use `dependsOn` only for real ordering. Independent tasks can run concurrently.

Do not put plugin setup into the plan. A task should describe the engineering outcome, not how to bootstrap Ponytail/agentmemory.

## 7. Inspect the result

When the run finishes, the harness prints the integration branch and useful commands.

List generated integration branches:

```bash
git branch --list 'agent/orchestrate/*'
```

Inspect commits:

```bash
git log --oneline <base>..agent/orchestrate/<run-branch>
```

Inspect the complete diff:

```bash
git diff <base>...agent/orchestrate/<run-branch>
```

Inspect run evidence:

```bash
find .git/agent-harness/runs -maxdepth 2 -type f | sort
```

A run normally contains:

```text
plan.json
status.json
summary.json
<task>.log
review.log
```

Only push/create a PR after you have reviewed the local integration branch.

## 8. Failure behavior

If a task fails:

```text
failed task
    ↓
dependent tasks become blocked
    ↓
independent already-running tasks may still finish
```

If two successful parallel tasks conflict while being integrated, the conflicting task fails. The harness does not silently ask an LLM to resolve the conflict.

If a configured final reviewer does not return an explicit `VERDICT: PASS`, the run is not considered successful.

## 9. Memory and skills

Use memory for history, not as the source of truth.

Authority order:

```text
current code/tests/GitHub requirements
        >
AGENTS.md + repository skills
        >
agentmemory
        >
general research
```

After verified work:

- save only durable decisions/root causes/outcomes to memory
- run `skill-maintenance` only when a reusable repository workflow or architectural invariant changed
- never store secrets in memory

Remember the distinction:

```text
Ponytail / agentmemory  = host runtime integrations
.agents/skills/*        = repository-specific version-controlled knowledge
```

## 10. Command cheat sheet

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

# orchestration
agent-harness orchestrate example
agent-harness orchestrate /tmp/plan.json --dry-run
agent-harness orchestrate /tmp/plan.json
```
