# agent-harness

A reusable coding harness for ChatGPT Web, Codex, Gemini CLI, Agent Skills, Ponytail, agentmemory, GitHub, and automatic multi-agent execution.

## Quick start

Prerequisites: Git, Bash, curl, Node.js 20+, Codex CLI. Gemini CLI is optional unless you want tasks assigned to Gemini.

From the Git repository you want to prepare:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

For the full setup, answer `Y` to Ponytail, Codex Web GPT, and keyless agentmemory. Then finish the one-time hook/restart steps in the setup guide.

Verify:

```bash
agent-harness doctor .
agent-harness version
```

## Daily use

```bash
agent-harness memory start       # safe if already running
agent-harness chatgpt-web open   # only for ChatGPT Web models
codex
```

For substantial work, ask the ChatGPT Web orchestrator to implement/orchestrate the task. It can dispatch Codex/Gemini automatically.

```bash
agent-harness orchestrate example
agent-harness orchestrate /tmp/plan.json --dry-run
agent-harness orchestrate /tmp/plan.json
```

The dispatcher works on local Git branches/worktrees and never pushes or merges remotely by itself.

## Documentation

| Read this | When |
|---|---|
| [First-time setup](docs/first-time-setup.md) | Installing the harness on a machine/project |
| [How to use](docs/usage.md) | Daily coding, orchestration, automatic dispatch, inspecting results |
| [Architecture](docs/architecture.md) | Understanding the execution model |
| [Orchestrator protocol](templates/docs/chatgpt-orchestrator.md) | Protocol copied into prepared projects as `docs/agent-orchestrator.md` |

## Main components

- `AGENTS.md` + `.agents/skills/` — engineering rules and repository knowledge
- **Ponytail** — host plugin/extension that reinforces minimal, YAGNI implementation behavior
- **agentmemory** — local memory service plus Codex/Gemini/Antigravity integration; persistent data stays outside repositories
- **Codex Web GPT** — optional ChatGPT Web model + Full Harness bridge
- **`agent-harness orchestrate`** — dependency-aware Codex/Gemini dispatcher with deterministic verification and final review

On Linux, persistent memory defaults to `~/.local/share/agentmemory` (or `$XDG_DATA_HOME/agentmemory`), not the project directory.
