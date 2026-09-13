# agent-harness

A reusable coding harness for ChatGPT Web, Codex, Antigravity/Gemini, Agent Skills, GitHub, Ponytail, and persistent local memory.

> **Enter a Git project, run one setup command, finish the guided prompts, then start coding.**

## Included features

| Feature | Purpose |
|---|---|
| `AGENTS.md` | Shared engineering rules for all coding agents |
| `skill-discovery` | Finds maintained external specialist skills for the active task |
| `repo-skill-bootstrap` | Finds project-specific knowledge that should become repository skills |
| `skill-maintenance` | Keeps project skills current after architecture changes |
| `shared-memory` | Teaches agents when and how to use historical memory |
| Ponytail | YAGNI/minimal-change guidance |
| `codex-chatgpt-web` | Lets ChatGPT Web operate through the local Codex Full Harness |
| `agentmemory` | Persistent local memory shared by Codex/Gemini/Antigravity through MCP |
| GitHub Issue/PR templates | Compact implementation and review contracts |
| Worktree helper | Isolated worktrees for parallel agents |

### Memory defaults

The harness configures `rohitg00/agentmemory` for this workflow:

- **no OpenAI/Gemini/Anthropic API key required**
- BM25 recall works in keyless mode
- `EMBEDDING_PROVIDER=local` enables free local MiniLM semantic embeddings
- `AGENTMEMORY_TOOLS=core` exposes the lean 8-tool MCP surface
- automatic LLM compression stays off
- broad automatic context injection stays off
- Codex, Gemini CLI, and Antigravity are wired automatically when detected

## Prerequisites

Install these before running the harness:

- Git
- Bash
- curl
- Node.js **20+** with npm/npx
- Codex CLI for the main workflow
- Antigravity/Gemini CLI only if you also use it

Docker is **not required** for the default memory setup.

## Setup — use this one command

Run this inside the Git repository you want to prepare:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

For the full workflow, answer:

```text
Install/update Ponytail for detected coding agents?       Y
Install/update the codex-chatgpt-web launcher?            Y
Set up keyless local agentmemory (no API key)?             Y
```

The command then:

1. installs/updates `agent-harness`
2. adds the repository rules, skills, GitHub templates, and worktree helper
3. installs Ponytail for detected agents
4. installs the ChatGPT-Web bridge when approved
5. starts local `agentmemory`
6. enables local semantic embeddings and the lean MCP tool set
7. wires agentmemory into Codex/Gemini/Antigravity when detected
8. runs a readiness check

## Finish the one-time setup

### 1. Trust Codex hooks

After Ponytail/agentmemory installation, launch the Codex TUI once:

```bash
codex
```

Review the **Hooks need review** prompt and trust only the hooks you accept, then restart Codex.

### 2. Finish ChatGPT-Web Full Harness setup

Open the installed `codex-chatgpt-web` launcher:

1. sign in to ChatGPT in its embedded browser
2. run the browser smoke test
3. install the ChatGPT Web models into Codex
4. enable **Full Harness** on its MCP page
5. follow the launcher instructions to create the ChatGPT Developer Mode connector (currently `Codex Native2`)
6. restart Codex

With Full Harness enabled, ChatGPT Web can use Codex's current local tool surface, including the configured agentmemory MCP tools.

### 3. Verify

```bash
agent-harness doctor .
agent-harness memory status
agent-harness version
```

You can also open the memory viewer at:

```text
http://127.0.0.1:3113
```

The memory REST/MCP service runs at `http://127.0.0.1:3111`.

## First use in a project

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

Approve only the useful project-specific skills, then have the agent create them under `.agents/skills/`.

## Daily use

Normally you now just enter the project and start Codex:

```bash
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

Agents should use `memory_smart_search` or `memory_recall` selectively, and save only durable verified lessons with `memory_save` / `memory_lesson_save`.

The authority order is always:

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
├── .agents/
│   └── skills/
│       ├── skill-discovery/
│       ├── repo-skill-bootstrap/
│       ├── skill-maintenance/
│       └── shared-memory/
├── .github/
│   ├── ISSUE_TEMPLATE/agent-task.md
│   └── pull_request_template.md
├── docs/
│   └── agent-orchestrator.md
└── scripts/
    └── agents/
        └── create-worktree.sh
```

The installer remains non-destructive. It only migrates known legacy Tencent-memory files created by older harness versions.

For the same flow with more troubleshooting detail, see [docs/one-command-setup.md](docs/one-command-setup.md). For architecture rationale only, see [docs/architecture.md](docs/architecture.md).
