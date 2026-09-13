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

## 3. Run the setup command

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

For the complete setup, answer:

```text
Install/update Ponytail for detected coding agents?       Y
Set up/open the Codex Web GPT launcher?                    Y
Set up keyless local agentmemory (no API key)?             Y
```

The bootstrap installs/updates the harness, prepares repository files, installs supported runtime plugins/extensions, starts memory in the background, configures MCP/adapters, and runs readiness checks.

Do not run the internal setup scripts manually during normal installation.

## 4. Finish the one-time plugin/hook step

The bootstrap installs two runtime integrations when supported:

```text
Ponytail
  → Codex plugin
  → Gemini extension
  → Antigravity plugin

agentmemory
  → Codex plugin + MCP/hooks
  → Gemini/Antigravity adapters
```

### Codex

Launch:

```bash
codex
```

Open `/hooks` if Codex reports hooks needing review. Inspect and trust only the Ponytail/agentmemory hooks you accept, then start a new thread or restart Codex.

You do this once after installation or after a plugin/hook update that requires new trust.

### Gemini / Antigravity

If Ponytail or agentmemory was installed while the host was already open, restart Gemini/Antigravity so the active session reloads the extension/plugin/MCP configuration.

After this step, you do **not** manually run Ponytail before each coding task. The coding host loads it when that agent starts. agentmemory is also available to the connected host, but agents should query it selectively rather than injecting all memory automatically.

See [Runtime plugins and extensions](plugins.md) for exactly how they affect interactive and orchestrated tasks.

## 5. Finish Codex Web GPT setup

Use Codex Web GPT only if you want a ChatGPT Web model to act through the local Codex tool surface.

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

Keep the launcher running while a ChatGPT Web model is being used inside Codex.

Codex Web GPT is a model/tool bridge, not the Ponytail or agentmemory plugin.

## 6. Verify the installation

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

## 7. Bootstrap repository-specific skills once

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

Review the proposed inventory first. Then approve only useful repository-specific skills and ask the agent to create them under `.agents/skills/`.

For a brand-new empty repository, establish the initial architecture/code first; bootstrap repository skills after real conventions exist.

Repository skills are different from runtime plugins:

```text
Ponytail / agentmemory
→ installed into the coding host
→ reusable across repositories

.agents/skills/*
→ stored in this repository
→ project-specific knowledge/workflows
```

## 8. Test the dispatcher safely

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

## 9. What happens when you later orchestrate work

Once setup is complete:

```text
ChatGPT Web orchestrator (optional)
          │
          ▼
agent-harness orchestrate
     ┌────────────┐
     ▼            ▼
   Codex        Gemini
     │            │
     ├─ Ponytail  ├─ Ponytail
     └─ memory    └─ memory
          │
          ▼
  repository worktrees
```

The spawned Codex/Gemini processes use their normal host configuration, so installed Ponytail/agentmemory integrations apply there too. You do not add plugin-install tasks to the orchestration plan.

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

Ponytail or agentmemory appears missing after setup:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

Then restart the affected coding host and review hooks again if prompted.

Gemini is not installed: use Codex-only orchestration plans, or install/configure Gemini before assigning a task to `gemini`.
