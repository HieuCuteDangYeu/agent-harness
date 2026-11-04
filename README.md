# agent-harness

A lightweight, **agent-neutral policy and integration layer for Orca**.
Choose any Orca-supported CLI as parent or worker (Codex, Claude Code,
Gemini, OpenCode, Antigravity, Cursor, Copilot, Pi, or a custom CLI).
The harness does not launch its own parallel orchestration runtime.

## Design

- **Current session first:** trivial/easy tasks run locally; moderate tasks
  normally do too. Delegate only for substantial complexity, specialist
  capability, independent verification, or safe worktree isolation.
- **Adaptive effort:** low for simple tasks, medium for bounded tasks, high
  for challenging work, highest supported effort for critical work.
- **Capability and quota:** rank available agents by task strength and the
  *active* account/model-group quota pool. Orca Usage is authoritative when
  available. Unknown or stale usage is not free quota.
- **Orca owns execution:** GUI, Runs, worktrees, worker sessions, review,
  and decision gates. The harness provides policy and an optional
  machine-readable **advisory** router; it never duplicates Orca.
- **Optional integrations:** Ponytail and agentmemory are opt-in and may
  support only some agent CLIs.

The legacy browser-bridge integration is **retired from setup**. The
harness does not install or uninstall previously configured machine-level
software. It relies on Orca-supported agent CLIs rather than a particular
chat product or subscription.

## Install

Install Orca from [onorca.dev](https://www.onorca.dev/docs/install),
register its CLI, then run inside a repository:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

This installs `AGENTS.md` and the managed compatibility skills. Orca's
version-matched orchestration skills are installed when available.

Optional setup:

```bash
agent-harness ready . --with-agentmemory
agent-harness ready . --with-ponytail
agent-harness doctor .
agent-harness orca guide
```

`ready` does **not** install optional agent-specific plugins by default.
Ponytail currently has Codex/Antigravity integration; agentmemory can
also be connected to compatible CLIs via their own MCP setup.

## Daily workflow

Open Orca, select the repository, and launch whichever configured agent
fits your task. For a small edit, ask it to execute directly. For complex
work, ask it to follow `AGENTS.md`, inspect Orca Usage, load the live
`orchestration` skill, use the smallest useful task graph, run tests and
independent review when warranted, and deliver only on PASS.

To inspect advisory routing with a fresh **manually verified** quota
snapshot:

```bash
agent-harness route --difficulty hard --domain backend \
  --config ~/.config/agent-harness/agents.json \
  --usage ~/.config/agent-harness/usage.json
```

The `route` helper uses Python 3 standard library only. It cannot
read live Orca quotas or start workers. See [Adaptive routing](docs/routing.md)
for configuration, limits, examples, and selection rules.

## Managed template upgrades

Untouched generated `AGENTS.md` and `.agents/skills/*` templates are
refreshed during bootstrap using the previous-template snapshot and a
historical hash catalog. Project-owned changes are preserved.

## Documentation

- [First-time setup](docs/first-time-setup.md)
- [Usage](docs/usage.md)
- [Architecture](docs/architecture.md)
- [Adaptive routing and quota snapshots](docs/routing.md)
- [Migration and template safety](docs/migration.md)
