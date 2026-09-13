# agent-harness

A reusable coding harness for ChatGPT Web, Codex, Antigravity/Gemini, Agent Skills, GitHub, Ponytail, and persistent local memory.

> **Enter a Git project, run one setup command, finish the guided UI steps, then start coding.**

## What you get

| Feature | Purpose |
|---|---|
| `AGENTS.md` | Shared engineering rules for coding agents |
| `skill-discovery` | Finds maintained external specialist skills for the active task |
| `repo-skill-bootstrap` | Finds project-specific knowledge that should become repository skills |
| `skill-maintenance` | Keeps project skills current after architecture changes |
| `shared-memory` | Teaches agents when and how to use historical memory |
| Ponytail | YAGNI/minimal-change guidance |
| Codex Web GPT | Uses your signed-in ChatGPT Web subscription as Codex models |
| `agentmemory` | Persistent local memory shared through MCP |
| GitHub Issue/PR templates | Compact implementation and review contracts |
| Worktree helper | Isolated worktrees for parallel agents |

`agentmemory` defaults to keyless local operation: BM25 recall, local MiniLM embeddings, the lean 8-tool MCP surface, no automatic LLM compression, and no broad automatic context injection. No OpenAI/Gemini/Anthropic API key is required. Persistent memory data is stored outside project repositories (`$XDG_DATA_HOME/agentmemory` or `~/.local/share/agentmemory` on Linux), so it does not pollute Git working trees.

## Prerequisites

Install these first:

- Git
- Bash
- curl
- Node.js **20+** with npm/npx
- Codex CLI
- Antigravity/Gemini CLI only if you also use it

Docker is not required for the default memory setup.

## Setup — one supported command

Run this inside the Git repository you want to prepare:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

For the complete workflow, answer:

```text
Install/update Ponytail for detected coding agents?       Y
Set up/open the Codex Web GPT launcher?                    Y
Set up keyless local agentmemory (no API key)?             Y
```

The harness then:

1. installs/updates itself
2. adds repository rules, skills, GitHub templates, and the worktree helper
3. installs Ponytail for detected agents
4. installs or opens Codex Web GPT
5. starts `agentmemory` **detached**, so setup returns your terminal
6. keeps agentmemory persistence outside the current Git repository
7. enables local semantic embeddings + the lean MCP tool surface
8. wires agentmemory into Codex/Gemini/Antigravity when detected
9. runs readiness checks

## Finish the one-time UI setup

### 1. Trust Codex hooks

Launch Codex once:

```bash
codex
```

Review the **Hooks need review** prompt for Ponytail/agentmemory, trust only the hooks you accept, then restart Codex.

### 2. Finish Codex Web GPT setup

Keep **Codex Web GPT running whenever you use a ChatGPT Web model inside Codex**.

In the launcher:

1. sign in to ChatGPT in its embedded browser
2. run the browser smoke test
3. install the ChatGPT Web models into Codex
4. enable **Full Harness** on the MCP page
5. follow the launcher instructions to create the ChatGPT Developer Mode connector (currently `Codex Native2`)
6. restart Codex

Full Harness exposes the current Codex tool surface to ChatGPT Web, including agentmemory MCP tools.

## Verify

Run:

```bash
agent-harness doctor .
agent-harness chatgpt-web status
agent-harness memory status
agent-harness memory data-dir
agent-harness version
```

Expected local endpoints:

```text
agentmemory REST/MCP  http://127.0.0.1:3111
agentmemory viewer    http://127.0.0.1:3113
```

On Linux the default persistent memory path is:

```text
~/.local/share/agentmemory
```

The runtime PID/log files are separate under `~/.local/state/agent-harness/agentmemory`.

## Lifecycle commands

You should not need raw installer commands after setup.

For Codex Web GPT:

```bash
agent-harness chatgpt-web status
agent-harness chatgpt-web open
agent-harness chatgpt-web repair
```

- `open` reopens the existing launcher without reinstalling it.
- `repair` reruns the official upstream launcher installer. Quit Codex Web GPT first.

For agentmemory:

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

The harness starts agentmemory in the background and writes its runtime log to:

```text
~/.local/state/agent-harness/agentmemory/service.log
```

If an old agentmemory run left `./data/state_store.db` or `./data/iii-config.yaml` inside a project, the harness will warn about it but will not delete or move it automatically. Inspect/migrate that legacy data before removing it. New harness-managed runs explicitly use the global data directory instead.

If you ever see the agentmemory ready panel followed by no shell prompt during bootstrap, that is the old foreground-start behavior from v0.4.0. Press `Ctrl+C`, rerun the one supported bootstrap command above, and v0.4.1+ will start it detached.

## First use in a repository

Start Codex:

```bash
codex
```

Then run this once:

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

Approve only useful project-specific skills, then have the agent create them under `.agents/skills/`.

## Daily use

Normally:

```bash
cd ~/Projects/my-project
codex
```

For implementation work:

```text
Implement GitHub issue #142.

Read AGENTS.md and relevant repository skills first.
Use Ponytail full when available.
Use agentmemory recall only if historical context can materially help.
Use skill-discovery if specialist external expertise would improve the task.
Treat the issue acceptance criteria as the contract.
Run the specified verification and review the final diff before completion.
```

Agents should use `memory_smart_search` / `memory_recall` selectively and save only durable verified lessons with `memory_save` / `memory_lesson_save`.

Authority remains:

```text
current code/tests/GitHub
        >
AGENTS.md + version-controlled skills
        >
agentmemory
```

## Project files installed

```text
project/
├── AGENTS.md
├── .agents/skills/
│   ├── skill-discovery/
│   ├── repo-skill-bootstrap/
│   ├── skill-maintenance/
│   └── shared-memory/
├── .github/
│   ├── ISSUE_TEMPLATE/agent-task.md
│   └── pull_request_template.md
├── docs/agent-orchestrator.md
└── scripts/agents/create-worktree.sh
```

The installer is non-destructive except for recognized obsolete harness-generated Tencent memory files, which are migrated/removed automatically.

For the same setup flow with troubleshooting detail, see [docs/one-command-setup.md](docs/one-command-setup.md). For design rationale only, see [docs/architecture.md](docs/architecture.md).
