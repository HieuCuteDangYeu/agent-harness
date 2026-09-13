# agent-harness

A reusable coding harness for ChatGPT Web, Codex, Gemini CLI, Agent Skills, GitHub, Ponytail, persistent local memory, and automatic multi-agent execution.

## Quick start

Prerequisites: Git, Bash, curl, Node.js 20+, Codex CLI. Gemini CLI is optional unless you want tasks assigned to Gemini.

From the Git repository you want to prepare:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

For the full setup, answer `Y` to Ponytail, Codex Web GPT, and keyless agentmemory. Then follow the one-time UI steps in the setup guide.

Verify:

```bash
agent-harness doctor .
agent-harness version
```

## Daily use

Start the optional local services, then open Codex:

```bash
agent-harness chatgpt-web open   # only when using ChatGPT Web models
agent-harness memory start       # safe if already running
codex
```

For substantial work, ask the ChatGPT Web orchestrator to implement or orchestrate the task. It can create a task graph and dispatch Codex/Gemini automatically.

Manual dispatcher entry points:

```bash
agent-harness orchestrate example
agent-harness orchestrate /tmp/plan.json --dry-run
agent-harness orchestrate /tmp/plan.json
```

The dispatcher works on local Git branches/worktrees and never pushes or merges remotely by itself.

## Documentation

| Read this | When |
|---|---|
| [First-time setup](docs/first-time-setup.md) | Installing on a machine/project for the first time |
| [How to use](docs/usage.md) | Daily coding, ChatGPT Web orchestration, automatic dispatch, inspecting results |
| [Architecture](docs/architecture.md) | Understanding why the harness is designed this way |
| [`docs/agent-orchestrator.md`](templates/docs/chatgpt-orchestrator.md) | The orchestrator protocol installed into each prepared project |

## Main components

- `AGENTS.md` — shared coding-agent contract
- `.agents/skills/` — repository skill discovery/bootstrap/maintenance + shared-memory guidance
- Codex Web GPT — ChatGPT Web model bridge; launcher stays open while Web models are in use
- agentmemory — keyless local shared memory, stored outside project repositories
- `agent-harness orchestrate` — dependency-aware Codex/Gemini dispatcher with deterministic verification and final review
- GitHub Issue/PR templates — compact task and review contracts

Memory defaults to local/keyless operation. On Linux, persistent memory lives under `~/.local/share/agentmemory` (or `$XDG_DATA_HOME/agentmemory`), not inside the project.
