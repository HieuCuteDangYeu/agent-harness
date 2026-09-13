# One-command setup

This is the **single supported onboarding path** for `agent-harness`.

## 1. Prerequisites

Install:

```text
git
bash
curl
Node.js 20+ with npm/npx
Codex CLI
```

Gemini CLI is optional but required for automatic `gemini` executor tasks. Antigravity remains optional for its interactive IDE workflow. Docker is not required for the default memory setup.

## 2. Enter the project

```bash
cd ~/Projects/my-project
```

## 3. Run exactly this setup command

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

For the complete workflow, answer:

```text
Install/update Ponytail for detected coding agents?       Y
Set up/open the Codex Web GPT launcher?                    Y
Set up keyless local agentmemory (no API key)?             Y
```

Do not run internal setup scripts yourself.

## 4. What the command configures

### Codex Web GPT

Keep Codex Web GPT running whenever Codex is using a ChatGPT Web model. Manage it through:

```bash
agent-harness chatgpt-web status
agent-harness chatgpt-web open
agent-harness chatgpt-web repair
```

### agentmemory

The harness configures keyless memory with local embeddings and the lean MCP tool set, starts it detached, and explicitly stores persistent data outside the current Git repository.

Linux default:

```text
~/.local/share/agentmemory
```

Local services:

```text
REST / MCP    http://127.0.0.1:3111
streams       :3112
viewer        http://127.0.0.1:3113
iii engine    :49134
```

Manage it through:

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

If an old run left `./data/state_store.db` or `./data/iii-config.yaml`, inspect/migrate it before deleting it. New harness-managed runs use the global data directory.

## 5. Finish the one-time UI steps

Launch `codex`, review/trust only the Ponytail/agentmemory hooks you accept, then restart Codex.

In Codex Web GPT: sign in to ChatGPT, run its browser smoke test, install the Web models, enable **Full Harness**, configure the requested ChatGPT Developer Mode connector, then restart Codex.

## 6. Verify

```bash
agent-harness doctor .
agent-harness chatgpt-web status
agent-harness memory status
agent-harness memory data-dir
agent-harness version
```

Expected:

```text
repository harness files        OK
Codex Web GPT                    installed / running when needed
Node 20+ + npx                   OK
agentmemory :3111                OK
Codex MCP config                 OK
memory data directory            outside the repository
```

## 7. Automatic multi-agent execution

The installed wrapper exposes:

```bash
agent-harness orchestrate example
agent-harness orchestrate /tmp/plan.json --dry-run
agent-harness orchestrate /tmp/plan.json
```

The JSON plan assigns each task to `codex` or `gemini`, declares real `dependsOn` edges, acceptance criteria, and deterministic verification commands. Independent tasks can run concurrently; dependent work waits until prerequisites are successfully integrated.

The dispatcher creates temporary worktrees, runs the assigned CLIs, verifies each task, integrates successful work into a local `agent/orchestrate-*` branch, blocks downstream work on failure/conflict, and optionally runs a final reviewer. Logs/status/summary are stored under `.git/agent-harness/runs/` and therefore do not pollute the working tree.

Nothing is pushed or merged remotely automatically.

For ChatGPT Web orchestration: a **plan-only** request stops after planning; an **implement/execute/build/fix/orchestrate** request should generate the JSON graph, dry-run it, then execute it through Full Harness. The generated `docs/agent-orchestrator.md` explains the protocol.

## 8. Bootstrap repository-specific skills once

Start Codex and ask:

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

## 9. Daily coding

```bash
cd ~/Projects/my-project
agent-harness chatgpt-web open   # when using ChatGPT Web models
agent-harness memory start       # safe no-op when already running
codex
```

For substantial work, tell the ChatGPT Web orchestrator to implement/orchestrate the task; it can now dispatch the task graph automatically.

For a normal single-agent implementation:

```text
Implement GitHub issue #142.

Read AGENTS.md and relevant repository skills first.
Use agentmemory recall only if historical context can materially help.
Treat the issue acceptance criteria as the contract.
Run the specified verification and review the final diff before completion.
```

## Project files installed

```text
AGENTS.md
.agents/skills/
├── skill-discovery/
├── repo-skill-bootstrap/
├── skill-maintenance/
└── shared-memory/
.github/
├── ISSUE_TEMPLATE/agent-task.md
└── pull_request_template.md
docs/agent-orchestrator.md
scripts/agents/create-worktree.sh
```

The runtime orchestration state is not a project file; it stays under Git metadata. Exact unmodified older generated orchestrator docs are migrated to the v0.5 protocol while user-edited copies are preserved.

For architecture rationale, see [architecture.md](architecture.md).
