# One-command setup

This is the **single supported onboarding path** for `agent-harness`.

## 1. Prerequisites

Install:

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

## 3. Run exactly this setup command

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

For the complete workflow, answer:

```text
Install/update Ponytail for detected coding agents?       Y
Set up/open the Codex Web GPT launcher?                    Y
Set up keyless local agentmemory (no API key)?             Y
```

The bootstrap performs the whole machine/project setup in order. Do not run the internal setup scripts yourself.

## 4. What the command configures

### Codex Web GPT

The harness installs the official upstream launcher if it is missing or opens the existing launcher if already installed.

Keep Codex Web GPT running whenever Codex is using a ChatGPT Web model.

After setup, manage it only through:

```bash
agent-harness chatgpt-web status
agent-harness chatgpt-web open
agent-harness chatgpt-web repair
```

`repair` reruns the official upstream launcher installer. Fully quit Codex Web GPT first because upstream intentionally refuses to replace a running launcher.

### agentmemory

The harness configures:

```text
EMBEDDING_PROVIDER=local
AGENTMEMORY_TOOLS=core
```

This provides keyless BM25 recall, local MiniLM semantic embeddings, the lean 8-tool MCP surface, no automatic LLM compression, and no broad automatic context injection.

The important lifecycle behavior is that **agent-harness starts agentmemory detached from the setup terminal**. The upstream default command is a foreground server; the harness wraps it in a background lifecycle so bootstrap can continue to MCP wiring and verification.

Persistent memory is also explicitly kept **outside the current Git repository**. On Linux the default is:

```text
~/.local/share/agentmemory
```

or `$XDG_DATA_HOME/agentmemory` when `XDG_DATA_HOME` is set. You can override it with `AGENTMEMORY_DATA_DIR`, but reuse the same path on every restart.

Local services:

```text
REST / MCP    http://127.0.0.1:3111
streams       :3112
viewer        http://127.0.0.1:3113
iii engine    :49134
```

Manage it only through:

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

Harness-managed logs are at:

```text
~/.local/state/agent-harness/agentmemory/service.log
```

The harness wires detected agents using upstream-supported adapters:

```text
Codex        → agentmemory connect codex --with-hooks
Antigravity  → agentmemory connect antigravity
Gemini CLI   → agentmemory connect gemini-cli
```

If an older agentmemory run left `./data/state_store.db` or `./data/iii-config.yaml` in a repository, the harness warns about it but does not move or delete it automatically. The explicit global data directory wins, so new harness-managed runs will not reuse that repository-local state. Inspect/migrate it before deleting it.

## 5. Finish the one-time UI steps

### Codex hooks

Launch:

```bash
codex
```

Review the **Hooks need review** prompt, trust only the Ponytail/agentmemory hooks you accept, then restart Codex.

### Codex Web GPT Full Harness

In the Codex Web GPT launcher:

1. sign in to ChatGPT in the embedded browser
2. run the browser smoke test
3. install the ChatGPT Web models into Codex
4. enable **Full Harness** from the MCP page
5. follow the launcher instructions to create the ChatGPT Developer Mode connector (currently `Codex Native2`)
6. restart Codex

Because agentmemory is a Codex MCP server, the same Full Harness tool surface can expose its memory tools to ChatGPT Web.

## 6. Verify

Run:

```bash
agent-harness doctor .
agent-harness chatgpt-web status
agent-harness memory status
agent-harness memory data-dir
agent-harness version
```

Expected:

```text
repository harness files        OK
Codex Web GPT                    installed / running when needed
Node 20+ + npx                   OK
agentmemory :3111                OK
Codex MCP config                 OK
memory data directory            outside the project repository
```

## 7. If setup appears stuck on the agentmemory panel

If you see a panel such as:

```text
agentmemory v...
REST API  http://localhost:3111
Viewer    http://localhost:3113
...
```

and never get the shell prompt back, you are running the old v0.4.0 foreground-start behavior. The service itself is already up; the installer is what is blocked.

Press:

```text
Ctrl+C
```

Then rerun the one supported bootstrap command from step 3. v0.4.1+ starts agentmemory detached and continues setup normally.

If startup later fails, use:

```bash
agent-harness memory status
agent-harness memory logs
agent-harness memory doctor
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

Normal use becomes:

```bash
cd ~/Projects/my-project
agent-harness chatgpt-web open   # only when you want ChatGPT Web models
agent-harness memory start       # safe no-op when already running
codex
```

A normal implementation prompt is:

```text
Implement GitHub issue #142.

Read AGENTS.md and relevant repository skills first.
Use Ponytail full when available.
Use agentmemory recall only if historical context can materially help.
Use skill-discovery if specialist external expertise would improve the task.
Treat the issue acceptance criteria as the contract.
Run the specified verification and review the final diff before completion.
```

Use `memory_smart_search` / `memory_recall` for selective history and `memory_save` / `memory_lesson_save` only for durable verified lessons.

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

Known Tencent-memory files from v0.3.x are migrated/removed only when they still contain the old harness-generated Tencent markers. Other existing project files remain untouched.

For architecture rationale, see [architecture.md](architecture.md). It intentionally does not define another setup method.
