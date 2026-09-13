# agent-harness

A reusable coding harness for projects that use ChatGPT Web, Codex, Antigravity/Gemini, Agent Skills, GitHub, Ponytail, and optional shared memory.

The goal is simple:

> **Enter a Git project, run one setup command, finish the guided prompts, then start coding.**

## What is included

| Feature | What it does | Installed by the harness |
|---|---|---:|
| `AGENTS.md` | Gives coding agents the same engineering rules: inspect first, keep changes surgical, preserve safety, verify before claiming completion | Yes |
| `skill-discovery` | Finds maintained external specialist skills for the current task, such as UI/UX, accessibility, security, testing, or migration skills | Yes |
| `repo-skill-bootstrap` | Finds stable project-specific knowledge that should become repository skills | Yes |
| `skill-maintenance` | Checks whether major changes require existing project skills to be updated | Yes |
| `shared-memory` | Teaches agents when to use shared historical memory and when current Git evidence must win | Yes |
| Ponytail | Adds YAGNI/minimal-change guidance to supported coding agents | Guided install |
| `codex-chatgpt-web` | Lets ChatGPT Web operate through the local Codex Full Harness tool surface | Guided install |
| TencentDB Agent Memory | Provides shared memory, extracted skills, Wiki, and CodeGraph through a local Docker sidecar | Guided install |
| `agent-memory` | Safe CLI for querying/writing Tencent memory without exposing raw SQLite/Mongo administration | Yes |
| GitHub Issue/PR templates | Keeps implementation tasks compact and reviewable | Yes |
| Worktree helper | Creates isolated worktrees for Codex/Antigravity tasks | Yes |

The harness does **not** install Codex, Docker, or your project's CI. Those are machine/project prerequisites.

## Prerequisites

Before the first run, make sure the machine has:

- Git
- Bash
- curl
- Codex CLI for the main workflow
- Docker running if you want shared memory
- Antigravity/Gemini CLI only if you also want to use it

## Setup — use this one command

Run this **inside the Git repository you want to prepare**:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

This is the supported setup path documented by this repository.

The command installs or updates `agent-harness`, prepares the current project, then asks which external integrations to configure.

For the complete workflow discussed by this project, answer:

```text
Install/update Ponytail for detected coding agents?       Y
Install/update the codex-chatgpt-web launcher?            Y
Provision TencentDB Agent Memory locally with Docker?     Y
```

The ChatGPT-Web bridge requires an explicit `Y` because it is an unofficial browser-automation integration and should not be enabled silently.

### During Tencent memory setup

The installer asks for the LLM Tencent uses to extract and organize memories:

```text
Memory LLM base URL:
Memory LLM model:
Memory LLM protocol: openai   # or anthropic
Memory LLM API key:
```

The harness starts only:

```text
memory-core       http://127.0.0.1:8420
Memory Hub        http://127.0.0.1:8125
knowledge         http://127.0.0.1:8424
```

Tencent's model proxy on `:8096` is intentionally **not** started. `codex-chatgpt-web` remains the ChatGPT/Codex model and tool bridge; Tencent is only the memory sidecar.

## Finish the one-time setup

After the command completes, finish these account/UI steps once:

### 1. Trust Ponytail in Codex

Start Codex, open:

```text
/hooks
```

Review and trust Ponytail's lifecycle hooks, then start a fresh Codex thread.

### 2. Connect ChatGPT Web to Codex

Open the installed `codex-chatgpt-web` launcher and complete its guided setup:

1. Sign in to ChatGPT in its embedded browser.
2. Run the browser smoke test.
3. Install the ChatGPT Web models into Codex.
4. Open the launcher's MCP page and enable **Full Harness**.
5. Follow the launcher instructions to create the ChatGPT Developer Mode connector (currently `Codex Native2`).
6. Restart Codex.

Full Harness is what allows ChatGPT Web to reach the current Codex repository, shell/tools, and `agent-memory` helper.

### 3. Verify the setup

From the prepared project:

```bash
agent-harness doctor .
agent-memory status
agent-harness version
```

A healthy setup should show the repository harness files as `OK`; if memory was enabled, `agent-memory status` should reach the local memory service.

## First use in a project

The harness installs the generic skills, but it cannot know your project's architecture until an agent inspects the repository.

Start Codex in the project:

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

Review the proposals. Then tell the agent to generate only the approved skills under `.agents/skills/` using the host's built-in skill creator when available.

After this, the project carries its own reusable architecture knowledge instead of making every agent rediscover it from scratch.

## Daily use

After the one-time setup, you normally do **not** rerun installation commands. Enter the project and start Codex:

```bash
codex
```

For a normal implementation task, use the GitHub Issue as the compact contract and give the agent a prompt like:

```text
Implement GitHub issue #142.

Read AGENTS.md and the relevant repository skills first.
Use Ponytail full when available.
Search shared memory only if historical context can materially help.
Use skill-discovery if specialist external expertise would improve this task.
Treat the issue acceptance criteria as the contract.
Run the specified verification and review the final diff before completion.
```

For example, a UI task can cause `skill-discovery` to recommend a maintained UI/UX skill instead of generating a generic local UI skill. A repository-specific rule such as your event-delivery or auth invariant belongs in a version-controlled project skill instead.

## How memory is used

Shared memory is for useful historical context, not for replacing the repository.

Agents should use it for things such as prior architecture decisions, past failure/root-cause patterns, and verified task outcomes. The authority order is:

```text
current code/tests/GitHub
        >
AGENTS.md + version-controlled skills
        >
shared memory
```

The `agent-memory` helper intentionally exposes narrow HTTP operations instead of raw database administration.

## Files added to a project

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
        ├── agent-memory
        └── create-worktree.sh
```

Existing managed files are not overwritten.

For a more detailed explanation of the exact same setup path, see [docs/one-command-setup.md](docs/one-command-setup.md). For design rationale only, see [docs/architecture.md](docs/architecture.md).
