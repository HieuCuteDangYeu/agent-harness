# First-time setup

Use this guide once per machine/project. After this, normal use is much shorter; see [How to use](usage.md).

## 1. Install prerequisites

Required:

```text
Git
Bash
curl
Node.js 20+ with npm/npx
Codex CLI
```

Optional:

```text
Gemini CLI     required only for automatic tasks assigned to `gemini`
Antigravity    optional interactive IDE/review workflow
```

Quick checks:

```bash
git --version
node --version
npx --version
codex --version
gemini --version   # optional
```

Docker is not required for the default memory setup.

## 2. Enter the Git repository

```bash
cd ~/Projects/my-project
git status
```

A clean working tree is recommended. The automatic dispatcher later requires committed Git state by default.

## 3. Run the single setup command

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

For the complete setup, answer:

```text
Install/update Ponytail for detected coding agents?       Y
Set up/open the Codex Web GPT launcher?                    Y
Set up keyless local agentmemory (no API key)?             Y
```

Do not run the internal setup scripts manually. The bootstrap installs/updates the harness, prepares the repository files, configures integrations, starts memory in the background, and runs readiness checks.

## 4. Finish Codex hook setup

Run:

```bash
codex
```

If Codex shows **Hooks need review**, inspect and trust only the Ponytail/agentmemory hooks you accept. Then fully restart Codex.

## 5. Finish Codex Web GPT setup

Use Codex Web GPT only if you want ChatGPT Web models inside Codex.

Open it with:

```bash
agent-harness chatgpt-web open
```

In the launcher:

1. sign in to ChatGPT in the embedded browser
2. run the browser smoke test
3. install the ChatGPT Web models into Codex
4. enable **Full Harness**
5. configure the ChatGPT Developer Mode connector requested by the launcher
6. restart Codex

Keep the launcher running while a ChatGPT Web model is being used in Codex.

## 6. Connect optional ChatGPT plugins

Plugins are **not installed by agent-harness**. They are optional data/action sources for the ChatGPT orchestrator when they are connected in ChatGPT.

Useful examples:

| Plugin | Use it for |
|---|---|
| GitHub | repositories, issues, PRs, CI, reviews, history |
| Google Drive | product requirements, design docs, reports, shared project documents |
| Figma | design inspection, UI implementation context, design handoff |
| Neon | PostgreSQL projects, branches, schema/runtime database inspection |
| OpenAI Platform | OpenAI API key/setup tasks when the project actually uses the API |
| Files | prior uploads and project files stored in ChatGPT |

The orchestrator should use only the plugins relevant to the current task. Connected plugins do **not** automatically become tools inside spawned Codex/Gemini executor processes. The orchestrator should extract only the few facts/references executors need and place those in the task packet.

See [Plugins and connectors](plugins.md) for the rules and examples.

## 7. Verify the installation

Run:

```bash
agent-harness version
agent-harness doctor .
agent-harness chatgpt-web status
agent-harness memory status
agent-harness memory data-dir
```

Expected behavior:

```text
repository harness files    OK
Codex                       detected
Codex Web GPT               installed/running when needed
Node 20+ + npx              OK
agentmemory :3111           reachable
Codex memory MCP            configured
memory data directory       outside the project repository
```

On Linux the default persistent memory path is:

```text
~/.local/share/agentmemory
```

The repository should not contain agentmemory state such as `data/state_store.db` from new harness-managed runs.

## 8. Bootstrap repository-specific skills once

For an existing repository, start Codex and ask:

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

Review the proposed inventory first. Then approve only the useful repository-specific skills and ask the agent to create them under `.agents/skills/`.

For a brand-new empty repository, establish the initial architecture/code first; bootstrap repository skills after real conventions exist.

## 9. Test the dispatcher safely

Print the example plan:

```bash
agent-harness orchestrate example
```

Validate it without launching agents:

```bash
agent-harness orchestrate example > /tmp/agent-plan.json
agent-harness orchestrate /tmp/agent-plan.json --dry-run
```

A successful dry run confirms the task-graph parser and dependency validation are ready. Real executor runs are explained in [How to use](usage.md).

## Troubleshooting

Codex Web GPT was closed:

```bash
agent-harness chatgpt-web open
```

Memory is stopped:

```bash
agent-harness memory start
agent-harness memory status
```

Memory diagnostics/logs:

```bash
agent-harness memory doctor
agent-harness memory logs
```

Gemini is not installed: use Codex-only orchestration plans, or install/configure Gemini before assigning a task to `gemini`.
