# agent-harness

A reusable coding harness for ChatGPT Web, Codex, Gemini CLI, Agent Skills, GitHub, Ponytail, persistent local memory, optional ChatGPT plugins, and automatic multi-agent execution.

## Quick start

Prerequisites: Git, Bash, curl, Node.js 20+, Codex CLI. Gemini CLI is optional unless you want tasks assigned to Gemini.

From the Git repository you want to prepare:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

For the full setup, answer `Y` to Ponytail, Codex Web GPT, and keyless agentmemory, then follow the one-time UI steps in the setup guide.

Verify:

```bash
agent-harness doctor .
agent-harness version
```

## Daily use

```bash
agent-harness chatgpt-web open   # only for ChatGPT Web models
agent-harness memory start       # safe if already running
codex
```

For substantial work, ask the ChatGPT Web orchestrator to implement/orchestrate the task. It can use relevant connected plugins for context, then dispatch Codex/Gemini automatically.

Manual dispatcher commands:

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
| [How to use](docs/usage.md) | Daily coding, orchestration, automatic dispatch, inspecting results |
| [Plugins and connectors](docs/plugins.md) | Using GitHub/Drive/Figma/Neon/OpenAI/Files with the orchestrator |
| [Architecture](docs/architecture.md) | Understanding why the harness is designed this way |
| [Orchestrator protocol](templates/docs/chatgpt-orchestrator.md) | The protocol copied into prepared projects as `docs/agent-orchestrator.md` |

## Main components

- `AGENTS.md` + `.agents/skills/` — engineering rules and repository knowledge
- Codex Web GPT — ChatGPT Web model + Full Harness bridge
- agentmemory — keyless local shared memory stored outside project repositories
- optional ChatGPT plugins — authoritative external project context when relevant
- `agent-harness orchestrate` — dependency-aware Codex/Gemini dispatcher with deterministic verification and final review

On Linux, persistent memory defaults to `~/.local/share/agentmemory` (or `$XDG_DATA_HOME/agentmemory`), not the project directory.
