# agent-harness

Multi-agent coding with ChatGPT Web, Codex, Gemini, Ponytail, and shared local memory.

## Setup

Requirements: Git, Bash, curl, Node.js 20+, Codex CLI. Gemini CLI is optional.

Run this inside the Git repository you want to use:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

Follow the prompts. For the full setup, enable Ponytail, Codex Web GPT, and agentmemory.

See [First-time setup](docs/first-time-setup.md) for the one-time Codex hook and ChatGPT Web steps.

## Use

```bash
agent-harness memory start
agent-harness chatgpt-web open   # only for ChatGPT Web models
codex
```

Then ask normally:

```text
Improve the reel recommendation system using the repository orchestrator.
Implement it, verify it, and do not push or merge remotely.
```

The orchestrator inspects the repo, creates the task graph internally, runs Codex/Gemini, verifies the result, and returns a local integration branch. You do not write plan JSON yourself.

## Docs

- [First-time setup](docs/first-time-setup.md)
- [How to use](docs/usage.md)
- [Architecture](docs/architecture.md)

Persistent agentmemory data stays outside the repository. On Linux it defaults to `~/.local/share/agentmemory`.
