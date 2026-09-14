# agent-harness

Multi-agent coding with ChatGPT Web, Codex native subagents, Antigravity (`agy`), Ponytail, and shared local memory.

## Setup

Run this inside the repository:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

See [First-time setup](docs/first-time-setup.md) for the one-time Codex hook and ChatGPT Web steps.

## Use

```bash
agent-harness memory start
agent-harness chatgpt-web open   # only for ChatGPT Web models
codex
```

Then ask normally:

```text
Implement this using the repository orchestrator.
Verify it and do not push or merge remotely.
```

The orchestrator plans internally, uses Codex native subagents and `agy` where useful, verifies and integrates isolated worktrees, updates repository skills when durable knowledge changes, then applies the verified patch back to your worktree. You do not create plan JSON or agents yourself.

## Docs

- [First-time setup](docs/first-time-setup.md)
- [How to use](docs/usage.md)
- [Architecture](docs/architecture.md)
