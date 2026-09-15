# agent-harness

A lightweight setup and policy layer for multi-agent coding with ChatGPT Web, Orca, Codex, Antigravity (`agy`), Ponytail, and shared local memory.

Orca now owns multi-agent Runs, worktrees, worker sessions, messages, and gates. `agent-harness` keeps the repository instructions, skills, ChatGPT Web bridge, Ponytail, and agentmemory setup around it.

## Setup

Install Orca first from [onorca.dev](https://www.onorca.dev/docs/install), then run this inside the repository:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

The setup detects Orca's CLI (`orca`, `orca-ide`, or `ORCA_CLI_COMMAND`) and installs the version-matched `orca-cli` and `orchestration` skills. If `adb` is available it also installs Orca's Android emulator skill.

See [First-time setup](docs/first-time-setup.md) for the one-time Orca, Codex, ChatGPT Web, and hook steps.

## Use

```bash
agent-harness memory start
agent-harness chatgpt-web open   # only for ChatGPT Web models
agent-harness orca open
```

Launch the parent Codex session in Orca, then ask normally:

```text
Implement this using the repository orchestrator.
Verify it and do not push or merge remotely.
```

The repository policy loads Orca's live orchestration guide and lets Orca manage the multi-session execution. You do not create worktrees, worker terminals, or orchestration state yourself.

## Docs

- [First-time setup](docs/first-time-setup.md)
- [How to use](docs/usage.md)
- [Architecture](docs/architecture.md)
