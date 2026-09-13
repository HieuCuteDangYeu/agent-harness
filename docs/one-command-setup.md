# One-command setup

This guide documents the **single supported onboarding path** for `agent-harness`.

Do not start by cloning this repository manually or by running individual setup scripts. The bootstrap command below installs/updates the harness and then runs the project setup in the correct order.

## 1. Check prerequisites

The machine should already have:

```text
Required:
- git
- bash
- curl
- Codex CLI

Required for shared memory:
- Docker running

Optional:
- Antigravity/Gemini CLI
```

The harness does not install Codex or Docker because those are machine-level choices.

## 2. Enter the project

Run the setup from the Git repository you actually want to prepare.

Example:

```bash
cd ~/Projects/my-project
```

## 3. Run the setup command

Run exactly:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

The bootstrap performs these operations in order:

1. installs or updates `agent-harness` under `~/.local/share/agent-harness`
2. links `agent-harness` and `agent-memory` into `~/.local/bin`
3. runs `agent-harness ready .` against the current repository
4. installs the repository harness files without overwriting existing managed files
5. detects Codex, Antigravity/Gemini, Docker, Git, and curl
6. offers Ponytail setup
7. offers `codex-chatgpt-web` setup
8. offers TencentDB Agent Memory setup
9. runs the harness readiness check
10. prints the remaining one-time account/UI steps

## 4. Answer the setup prompts

For the complete workflow, choose `Y` for all three integrations:

```text
Install/update Ponytail for detected coding agents?       Y
Install/update the codex-chatgpt-web launcher?            Y
Provision TencentDB Agent Memory locally with Docker?     Y
```

Why each one exists:

| Integration | Purpose |
|---|---|
| Ponytail | Keeps implementations simple, surgical, and YAGNI-oriented |
| `codex-chatgpt-web` | Makes ChatGPT Web available through Codex and exposes the Full Harness local tool surface |
| TencentDB Agent Memory | Gives Codex/ChatGPT/other agents shared historical memory, extracted skills, Wiki, and CodeGraph |

`codex-chatgpt-web` requires an explicit `Y` because it is an unofficial browser-automation integration. The harness does not silently enable it.

## 5. Configure the memory LLM when prompted

If Tencent memory is enabled, the setup asks for:

```text
Memory LLM base URL:
Memory LLM model:
Memory LLM protocol: openai   # or anthropic
Memory LLM API key:
```

This model is used by Tencent Memory for extraction and knowledge processing. It is separate from the ChatGPT Web model used through Codex.

The harness starts:

```text
memory-core       http://127.0.0.1:8420
Memory Hub        http://127.0.0.1:8125
knowledge         http://127.0.0.1:8424
```

The Tencent model proxy on `:8096` is deliberately not started. The architecture is:

```text
ChatGPT Web
    ↓
codex-chatgpt-web
    ↓
Codex Full Harness
    ├── repository / shell / tools
    └── agent-memory
            ↓
     TencentDB Agent Memory
```

## 6. Finish the one-time Ponytail setup

If Ponytail was installed for Codex:

1. start Codex
2. open `/hooks`
3. review and trust Ponytail's lifecycle hooks
4. start a fresh thread

If Ponytail was installed for Antigravity/Gemini during an active session, restart that agent after setup.

## 7. Finish the one-time ChatGPT Web setup

Open the installed `codex-chatgpt-web` launcher and complete the launcher workflow:

1. sign in to ChatGPT in the embedded browser
2. run the browser smoke test
3. install the ChatGPT Web models into Codex
4. open the launcher's MCP page
5. enable **Full Harness**
6. follow the launcher instructions to create the ChatGPT Developer Mode connector (currently `Codex Native2`)
7. restart Codex

Full Harness is required if ChatGPT Web should access the current repository, local Codex tools, and `agent-memory`.

## 8. Verify the result

From the prepared project, run:

```bash
agent-harness doctor .
agent-memory status
agent-harness version
```

Expected result:

- repository harness files report `OK`
- `agent-memory status` reaches `127.0.0.1:8420` when memory was enabled
- `agent-harness version` prints the installed harness version

If `~/.local/bin` is not on your shell `PATH`, the bootstrap prints a note. Add it to your shell configuration before relying on `agent-harness` or `agent-memory` from new terminals.

## 9. Bootstrap project-specific skills once

Generic framework knowledge should not be copied into local skills. The useful local skills are the non-obvious rules specific to the repository.

Start Codex from the project:

```bash
codex
```

Then use:

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

Review the proposals, then tell the agent to generate only the approved skills under `.agents/skills/` using the host's built-in skill creator when available.

This is usually a one-time project bootstrap. Run `skill-maintenance` after meaningful architecture changes rather than regenerating everything repeatedly.

## 10. Start normal coding

After machine setup and project skill bootstrap, daily work is intentionally simple:

```bash
cd ~/Projects/my-project
codex
```

Use a GitHub Issue as the compact task contract. A normal executor prompt is:

```text
Implement GitHub issue #142.

Read AGENTS.md and relevant repository skills first.
Use Ponytail full when available.
Search shared memory only if historical context can materially help.
Use skill-discovery if specialist external expertise would improve the task.
Treat the issue acceptance criteria as the contract.
Run the specified verification and review the final diff before completion.
```

The agent should then:

```text
relevant memory only when useful
        ↓
current repository inspection
        ↓
relevant project skills
        ↓
external skill-discovery when useful
        ↓
implementation
        ↓
existing project CI/tests
        ↓
review
        ↓
record only durable lessons
```

## What the harness adds to the project

```text
AGENTS.md
.agents/skills/
├── skill-discovery/
├── repo-skill-bootstrap/
├── skill-maintenance/
└── shared-memory/
.github/
├── ISSUE_TEMPLATE/agent-task.md
└── pull_request_template.md
docs/agent-orchestrator.md
scripts/agents/
├── agent-memory
└── create-worktree.sh
```

The harness is non-destructive: if one of its managed target paths already exists, it keeps the project's existing file instead of overwriting it.

## What each skill is for

### `skill-discovery`

Use when the current task may benefit from maintained external expertise. For example, a UI task may benefit from an external UI/UX skill. The skill should verify provenance and compatibility before recommending installation.

### `repo-skill-bootstrap`

Use to discover repository-specific architecture, invariants, and workflows that future agents should not have to rediscover.

### `skill-maintenance`

Use after major architecture changes to decide whether a version-controlled repository skill should be updated, added, or removed.

### `shared-memory`

Use for selective historical context such as prior architecture decisions, resolved failure patterns, or verified task outcomes. Memory is advisory; current repository evidence always wins.

## Normal usage rule

After initial setup, do not keep running individual installation scripts. The normal lifecycle is:

```text
new machine/project → run the bootstrap command
project onboarding  → run repo-skill-bootstrap once
normal day          → start Codex and work from a GitHub issue
major architecture  → run skill-maintenance
```

For architecture rationale, see [architecture.md](architecture.md). It intentionally does not define another setup method.
