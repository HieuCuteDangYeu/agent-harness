# One-command setup

This is the **single supported onboarding path** for `agent-harness`.

## 1. Prerequisites

Install these first:

```text
git
bash
curl
Node.js 20+ with npm/npx
Codex CLI
```

Antigravity/Gemini CLI is optional. Docker is not required for the default memory setup.

## 2. Enter the project

```bash
cd ~/Projects/my-project
```

## 3. Run the setup command

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

The command:

1. installs or updates `agent-harness` under `~/.local/share/agent-harness`
2. links `agent-harness` into `~/.local/bin`
3. runs `agent-harness ready .`
4. installs the repository harness files
5. detects Codex, Antigravity/Gemini, Node, npx, Git, and curl
6. offers Ponytail setup
7. offers `codex-chatgpt-web` setup
8. offers keyless local `agentmemory` setup
9. wires agentmemory into detected coding agents
10. runs readiness checks

## 4. Answer the prompts

For the complete workflow:

```text
Install/update Ponytail for detected coding agents?       Y
Install/update the codex-chatgpt-web launcher?            Y
Set up keyless local agentmemory (no API key)?             Y
```

### What agentmemory setup does

The harness uses the upstream `@agentmemory/agentmemory@latest` runtime and configures:

```text
EMBEDDING_PROVIDER=local
AGENTMEMORY_TOOLS=core
```

That gives you:

- keyless BM25 recall
- free on-device MiniLM semantic embeddings
- the lean 8-tool MCP surface instead of all 54 tools
- no automatic LLM compression
- no broad automatic context injection
- no OpenAI, Gemini, or Anthropic API key requirement

The first semantic-memory request downloads `Xenova/all-MiniLM-L6-v2` once. After that, embedding inference runs locally.

The local services are:

```text
REST / MCP    http://127.0.0.1:3111
streams       :3112
viewer        http://127.0.0.1:3113
iii engine    :49134
```

The harness also runs the supported agentmemory adapters for detected agents:

```text
Codex        → agentmemory connect codex --with-hooks
Antigravity  → agentmemory connect antigravity
Gemini CLI   → agentmemory connect gemini-cli
```

For Codex it also attempts the upstream Codex plugin install before hook wiring.

## 5. Trust Codex hooks once

Start the Codex TUI:

```bash
codex
```

Review the **Hooks need review** prompt. Trust only the Ponytail/agentmemory hooks you accept, then restart Codex.

## 6. Finish ChatGPT-Web Full Harness setup once

Open the installed `codex-chatgpt-web` launcher:

1. sign in to ChatGPT in its embedded browser
2. run the browser smoke test
3. install the ChatGPT Web models into Codex
4. enable **Full Harness** from its MCP page
5. follow the launcher instructions to create the ChatGPT Developer Mode connector (currently `Codex Native2`)
6. restart Codex

Because agentmemory is registered as a Codex MCP server, ChatGPT Web can reach the memory tools through the same Full Harness tool surface.

## 7. Verify

Run:

```bash
agent-harness doctor .
agent-harness memory status
agent-harness memory doctor
```

Expected:

```text
repository harness files        OK
Node 20+ + npx                   OK
agentmemory :3111                OK
Codex MCP config                 OK   (when Codex is installed)
```

You can inspect memory visually at:

```text
http://127.0.0.1:3113
```

## 8. Bootstrap repository-specific skills once

Start Codex and ask:

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

Approve only useful repository-specific skills, then have the agent create them under `.agents/skills/`.

## 9. Daily coding

After setup, normal use is just:

```bash
cd ~/Projects/my-project
codex
```

A normal task prompt is:

```text
Implement GitHub issue #142.

Read AGENTS.md and relevant repository skills first.
Use Ponytail full when available.
Use agentmemory recall only if historical context can materially help.
Use skill-discovery if specialist external expertise would improve the task.
Treat the issue acceptance criteria as the contract.
Run the specified verification and review the final diff before completion.
```

For historical context, agents should prefer:

```text
memory_smart_search
memory_recall
```

For durable verified outcomes:

```text
memory_save
memory_lesson_save
```

Do not save secrets, raw logs, transient details, or speculative conclusions.

## Project files installed

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
scripts/agents/create-worktree.sh
```

Known Tencent-memory files from v0.3.x are migrated/removed when they still contain the old harness-generated Tencent markers. Other existing project files remain untouched.

## Lifecycle

```text
new machine/project → run the bootstrap command
project onboarding  → run repo-skill-bootstrap once
normal day          → start Codex and work from a GitHub issue
major architecture  → run skill-maintenance
memory health       → agent-harness memory status
```

For architecture rationale, see [architecture.md](architecture.md). It intentionally does not define another setup method.
