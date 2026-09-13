# First-time setup

Do this once for each project.

## 1. Open the repository

```bash
cd ~/Projects/my-project
```

A clean Git working tree is recommended.

## 2. Run the setup script

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

For the full setup, answer `Y` to:

```text
Ponytail
Codex Web GPT
agentmemory
```

The script installs or updates the harness, prepares the repo files, configures supported agent integrations, and starts local memory.

## 3. Finish Codex hooks

Run:

```bash
codex
```

If Codex shows hooks that need review, open `/hooks`, inspect Ponytail and agentmemory hooks, trust only the hooks you accept, then restart Codex or start a new thread.

You only repeat this after a hook/plugin update that asks for review.

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

Keep Codex Web GPT open while using a Web model.

## 5. Verify

```bash
agent-harness version
agent-harness doctor .
agent-harness memory status
agent-harness chatgpt-web status
```

Memory should use a global data directory, not the project. On Linux the default is:

```text
~/.local/share/agentmemory
```

## Optional: create repository skills

For an existing codebase, you can ask Codex:

```text
Use repo-skill-bootstrap to inspect this repository.
Propose only high-value repository-specific skills.
Do not create them until I approve the inventory.
```

For a new empty repo, wait until real architecture and conventions exist.

After setup, continue with [How to use](usage.md).
