# First-time setup

## 1. Install Orca and register its CLI

Install [Orca](https://www.onorca.dev/docs/install), launch it, and
register the CLI in **Settings -> General -> Orca CLI**. On Linux it
may be named `orca-ide`; `ORCA_CLI_COMMAND` overrides discovery.

In Orca Settings -> Agents, inspect enabled CLI agents, model choices,
reasoning effort, host permissions, and account-specific usage. You
may use Codex, Claude Code, Gemini, OpenCode, Antigravity, Cursor, Pi,
or another configured CLI. There is no required parent provider.

## 2. Install the repository harness

From your project checkout:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

This initializes managed `AGENTS.md` and compatibility skills and
attempts setup of Orca's official `orca-cli` and `orchestration`
skills. It does **not** install optional agent plugins by default.

Optionally configure compatible integrations:

```bash
agent-harness ready . --with-ponytail
agent-harness ready . --with-agentmemory
```

Ponytail and automatic agentmemory wiring currently cover a subset of
CLI agents. Other CLIs remain fully eligible for Orca and can use their
own MCP/skill integration if supported. No API key is required for
the local MiniLM agentmemory setup.

## 3. Learn routing

Read [Adaptive routing](routing.md). By default, do easy tasks in your
current session. When complex work needs specialist workers, compare
actual available agents, reasoning levels, account/model pool quotas,
and tool access in Orca. For a reproducible recommendation, use the
optional router with your own profile and fresh manually checked
quota snapshot. Do **not** use the example as if its numbers were live.

Orca Usage tracks multiple agents and reset windows, but a stable
all-provider quota export API is not assumed.

## 4. Verify

```bash
agent-harness version
agent-harness doctor .
agent-harness orca doctor
agent-harness orca guide
```

Start an Orca parent agent in the intended worktree. Before delegating,
inspect `git status --short`: newly created worktrees do not inherit
uncommitted modifications from other checkouts. The parent should not
silently stash, commit, or discard user edits.

## Removed Codex Web GPT setup

The unofficial Codex Web GPT bridge is no longer installed, launched,
repaired, or tested by this harness. An existing machine-level install
is left untouched; remove it manually using the bridge's own guidance
only if you choose. ChatGPT Work handles eligible web/desktop tasks
separately and is not automatically an Orca CLI model/provider.

Continue with [Usage](usage.md).
