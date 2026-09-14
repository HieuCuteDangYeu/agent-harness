# First-time setup

Do this once for each project.

## 1. Open the repository

```bash
cd ~/Projects/my-project
```

## 2. Run the setup script

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

For the full setup, answer `Y` to Ponytail, Codex Web GPT, and agentmemory.

Antigravity (`agy`) is optional. Codex is the primary coding host and repository orchestration uses its built-in subagents when they are available.

## 3. Finish Codex hooks

Run:

```bash
codex
```

If Codex asks you to review hooks, open `/hooks`, inspect Ponytail and agentmemory hooks, trust only the hooks you accept, then start a new thread.

## 4. Finish ChatGPT Web setup

Only needed if you want a ChatGPT Web model inside Codex.

```bash
agent-harness chatgpt-web open
```

In the launcher:

1. sign in to ChatGPT
2. run the browser smoke test
3. install the Web models into Codex
4. enable **Full Harness**
5. finish the connector setup shown by the launcher
6. restart Codex

Keep Codex Web GPT open while using a Web model. It is only the parent bridge; repository workers are Codex native subagents and optional `agy` tasks.

## 5. Verify

```bash
agent-harness version
agent-harness doctor .
agent-harness memory status
agent-harness chatgpt-web status
```

Memory data stays outside the project. On Linux the default is:

```text
~/.local/share/agentmemory
```

## Optional: create repository skills

For an existing codebase:

```text
Use repo-skill-bootstrap to inspect this repository.
Propose only high-value repository-specific skills.
Do not create them until I approve the inventory.
```

After setup, continue with [How to use](usage.md).
