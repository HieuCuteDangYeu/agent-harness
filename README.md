# agent-harness

A reusable coding harness for ChatGPT Web, Codex, Gemini/Antigravity, Agent Skills, GitHub, Ponytail, persistent local memory, and automatic multi-agent execution.

> **Enter a Git project, run one setup command, finish the guided UI steps, then start coding.**

## What you get

| Feature | Purpose |
|---|---|
| `AGENTS.md` | Shared engineering rules for coding agents |
| `skill-discovery` | Finds maintained external specialist skills for the active task |
| `repo-skill-bootstrap` | Finds project-specific knowledge that should become repository skills |
| `skill-maintenance` | Keeps project skills current after architecture changes |
| `shared-memory` | Teaches agents when and how to use historical memory |
| Ponytail | YAGNI/minimal-change guidance |
| Codex Web GPT | Uses your signed-in ChatGPT Web subscription as Codex models |
| `agentmemory` | Persistent local memory shared through MCP |
| `agent-harness orchestrate` | Dispatches Codex/Gemini tasks, schedules dependencies, integrates results, verifies, and reviews |
| GitHub Issue/PR templates | Compact implementation and review contracts |
| Worktree helper | Isolated worktrees for manual parallel-agent work |

`agentmemory` defaults to keyless local operation: BM25 recall, local MiniLM embeddings, the lean MCP surface, no automatic LLM compression, and no broad automatic context injection. Persistent data lives outside project repositories (`$XDG_DATA_HOME/agentmemory` or `~/.local/share/agentmemory` on Linux).

## Prerequisites

Install:

- Git
- Bash
- curl
- Node.js **20+** with npm/npx
- Codex CLI
- Gemini CLI if you want automatic Gemini-role execution
- Antigravity only if you also use its interactive IDE workflow

Docker is not required for the default memory setup.

## Setup — one supported command

Run inside the Git repository you want to prepare:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

For the complete workflow, answer:

```text
Install/update Ponytail for detected coding agents?       Y
Set up/open the Codex Web GPT launcher?                    Y
Set up keyless local agentmemory (no API key)?             Y
```

The harness installs/updates itself, adds repository rules/skills/templates, configures the local integrations, keeps memory persistence outside the repository, and runs readiness checks.

## Finish the one-time UI setup

Launch `codex` once and review/trust only the Ponytail/agentmemory hooks you accept, then restart Codex.

For Codex Web GPT, keep the launcher running whenever you use a ChatGPT Web model inside Codex. Sign in to ChatGPT in the embedded browser, run its smoke test, install the Web models, enable Full Harness, configure the requested Developer Mode connector, and restart Codex.

## Verify

```bash
agent-harness doctor .
agent-harness chatgpt-web status
agent-harness memory status
agent-harness memory data-dir
agent-harness version
```

Expected memory endpoints:

```text
REST/MCP  http://127.0.0.1:3111
viewer    http://127.0.0.1:3113
```

On Linux the default persistent memory path is `~/.local/share/agentmemory`; lifecycle PID/log state is separate under `~/.local/state/agent-harness/agentmemory`.

## Lifecycle commands

Codex Web GPT:

```bash
agent-harness chatgpt-web status
agent-harness chatgpt-web open
agent-harness chatgpt-web repair
```

agentmemory:

```bash
agent-harness memory status
agent-harness memory start
agent-harness memory stop
agent-harness memory restart
agent-harness memory logs
agent-harness memory viewer
agent-harness memory data-dir
agent-harness memory doctor
agent-harness memory upgrade
```

If an old agentmemory run left `./data/state_store.db` or `./data/iii-config.yaml`, inspect/migrate it before deleting it. New harness-managed runs explicitly use the global data directory.

## Automatic multi-agent orchestration

The v0.5 dispatcher turns the orchestrator's assignments into actual local agent runs:

```text
ChatGPT Web orchestrator
        ↓
JSON task graph
        ↓
agent-harness orchestrate
        ↓
 ┌─────────────┬─────────────┐
 ↓             ↓             │
Codex A      Gemini B        │ independent tasks can run concurrently
 └──────┬──────┘             │
        ↓ dependencies       │
      Codex C                │
        ↓                    │
 deterministic verification │
        ↓                    │
 integration branch ◀────────┘
        ↓
 final reviewer
```

Get the schema/example:

```bash
agent-harness orchestrate example
```

Validate a plan without executing anything:

```bash
agent-harness orchestrate /tmp/plan.json --dry-run
```

Execute it:

```bash
agent-harness orchestrate /tmp/plan.json
```

A plan contains `goal`, `tasks`, real `dependsOn` edges, executor assignment (`codex` or `gemini`), acceptance criteria, deterministic `verify` commands, and an optional final `review` block. Default concurrency is 2 and can be raised to 8.

The dispatcher:

- creates an isolated local integration branch (`agent/orchestrate-*`)
- creates a temporary worktree for each task
- starts independent tasks concurrently
- waits for dependencies before starting downstream work
- uses Codex `exec --approve-for-me` for Codex tasks
- uses Gemini `auto_edit` by default; `"approval": "yolo"` is explicit opt-in
- runs the declared verification commands itself
- commits uncommitted successful task changes and integrates them
- blocks dependent work after failures or merge conflicts
- runs the configured final reviewer and honors `VERDICT: BLOCK`
- stores plan/logs/status/summary under `.git/agent-harness/runs/...`, so runtime state does not pollute the working tree
- never pushes or merges a remote branch automatically

At completion it prints the integration branch plus exact `git diff`, `git log`, and optional `git push` commands.

### Using it from the ChatGPT Web orchestrator

A **plan-only** request should stop after planning. When you ask to **implement, execute, fix, build, or orchestrate**, the ChatGPT Web orchestrator should generate the compact JSON task graph, dry-run validate it, then invoke `agent-harness orchestrate` through Full Harness. The repository template at `docs/agent-orchestrator.md` contains this protocol.

## First use in a repository

Start Codex and bootstrap repository-specific knowledge once:

```text
Use repo-skill-bootstrap to analyze this repository.

Do not create skills yet.
Return the proposed repository-specific skill inventory with:
- skill name
- trigger
- repository evidence
- important invariants
- why it belongs in a skill instead of AGENTS.md

Do not propose generic technology skills.
```

Approve only useful repository-specific skills, then have the agent create them under `.agents/skills/`.

## Daily use

For a normal single-agent task:

```bash
cd ~/Projects/my-project
codex
```

For a substantial execution request, ask the ChatGPT Web orchestrator to implement/orchestrate it; it can dispatch the resulting task graph automatically.

Agents should recall memory selectively and save only durable verified lessons. Authority remains:

```text
current code/tests/GitHub
        >
AGENTS.md + version-controlled skills
        >
agentmemory
```

## Project files installed

```text
project/
├── AGENTS.md
├── .agents/skills/
│   ├── skill-discovery/
│   ├── repo-skill-bootstrap/
│   ├── skill-maintenance/
│   └── shared-memory/
├── .github/
│   ├── ISSUE_TEMPLATE/agent-task.md
│   └── pull_request_template.md
├── docs/agent-orchestrator.md
└── scripts/agents/create-worktree.sh
```

The installer is non-destructive except for recognized obsolete harness-generated files. An exact unmodified v0.4 orchestrator document is automatically migrated to the v0.5 dispatch protocol; user-edited copies are left untouched.

For detailed onboarding/troubleshooting, see [docs/one-command-setup.md](docs/one-command-setup.md). For design rationale, see [docs/architecture.md](docs/architecture.md).
