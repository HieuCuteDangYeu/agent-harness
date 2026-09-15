# First-time setup

Do this once for each development machine/project.

## 1. Install Orca

Install the Orca desktop app from the official site:

- https://www.onorca.dev/docs/install

On Linux the CLI may be named `orca-ide`; the harness also respects `ORCA_CLI_COMMAND` when you need to point at another Orca executable.

Open Orca once and register its CLI if it is not already on `PATH`.

## 2. Open the repository

```bash
cd ~/Projects/my-project
```

## 3. Run the harness setup

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

When Orca is detected, setup installs its version-matched `orca-cli` and `orchestration` skills. If `adb` is available it also installs `orca-emulator-android`.

For the full harness, answer `Y` to Ponytail, Codex Web GPT, and agentmemory when prompted.

## 4. Configure Orca

Open Orca and add the repository. Review **Settings → Agents** before autonomous work.

Orca currently ships supported agents with autonomy/bypass launch flags by default. Start with Manual permissions if you want to inspect shell/tool requests while learning the workflow, then loosen them only when you understand the trust boundary of your local machine and worktrees.

Use Orca's agent picker for Codex and Antigravity sessions so Orca can track their status and session lifecycle.

## 5. Finish Codex hooks

Launch Codex (inside Orca is fine):

```bash
codex
```

If Codex asks you to review hooks, open `/hooks`, inspect Ponytail and agentmemory hooks, trust only the hooks you accept, then start a new session.

## 6. Finish ChatGPT Web setup

Only needed if you want a ChatGPT Web model as the parent planner inside Codex.

```bash
agent-harness chatgpt-web open
```

In the launcher:

1. sign in to ChatGPT
2. run the browser smoke test
3. install the Web models into Codex
4. enable Full Harness
5. finish the connector setup shown by the launcher
6. restart the Codex session in Orca

Keep Codex Web GPT open while using a Web model. It remains only the parent transport; Orca owns repository worker sessions.

## 7. Verify

```bash
agent-harness version
agent-harness doctor .
agent-harness orca doctor
agent-harness memory status
agent-harness chatgpt-web status
```

Memory data stays outside the project. On Linux the default is:

```text
~/.local/share/agentmemory
```

## Important: dirty working trees

A new Orca worktree starts from a Git ref/commit. Uncommitted changes in another checkout are not automatically copied into it.

If an orchestration task depends on your current uncommitted edits, commit/snapshot them first or continue from an Orca-managed branch/worktree that already contains those changes. The repository-orchestrator policy deliberately fails closed instead of pretending the worker sees dirty state.

After setup, continue with [How to use](usage.md).
