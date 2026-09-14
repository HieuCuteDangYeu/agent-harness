# agent-harness

Multi-agent coding with ChatGPT Web, Codex native subagents, Antigravity (`agy`), Ponytail, and shared local memory.

## Setup

Run this inside the repository:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

See [First-time setup](docs/first-time-setup.md) for the one-time Codex/Web steps.

## Use

```bash
agent-harness memory start
agent-harness agy start           # only if you use Antigravity
agent-harness chatgpt-web open    # only for ChatGPT Web models
codex
```

Then ask normally:

```text
Implement this using the repository orchestrator.
Verify it and do not push or merge remotely.
```

Codex work uses native subagents. `agy` work runs through a small host-side runner so Antigravity keeps its normal local runtime instead of inheriting the Codex/Web sandbox. The harness handles isolated worktrees, verification, integration, skill maintenance, and delivery.

## Docs

- [First-time setup](docs/first-time-setup.md)
- [How to use](docs/usage.md)
- [Architecture](docs/architecture.md)
