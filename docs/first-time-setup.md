# First-time setup

Do this once for each development machine/project. This workflow is **Orca GUI first**: use the desktop app for repositories, worktrees, sessions, skills, reviews, and shipping; use the CLI mainly for agent-facing automation, diagnostics, and the live version-matched Orca guides.

## 1. Install Orca Desktop

Install Orca from the official site:

- https://www.onorca.dev/docs/install

Open Orca once, then register its CLI from **Settings → General → Orca CLI**. On Linux the executable may resolve as `orca-ide`; the harness also respects `ORCA_CLI_COMMAND`.

The CLI still matters because Orca's Agent Skills load their current guide from the installed Orca version, but you do not need to manage normal worktrees or sessions from a terminal.

## 2. Add the repository in Orca

Use **Add Repo** in the Orca sidebar and select the local checkout. Orca will use the repository's base ref for new worktrees.

Prefer the Orca GUI for:

- creating/selecting worktrees
- choosing Codex or Antigravity
- watching multiple sessions
- reviewing diffs
- inspecting agent activity and Runs
- updating skills
- commit/push/PR actions when explicitly desired

## 3. Run the harness setup

From the repository checkout:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

For the full setup, enable the integrations you actually use:

- Ponytail
- Codex Web GPT
- agentmemory

The harness can install Orca's `orca-cli` and `orchestration` skills. If `adb` is available it also installs `orca-emulator-android`.

## 4. Review Orca Agents and Skills in the GUI

Open **Settings → Agents** and review:

- detected Codex / Antigravity agents
- Agent Permissions
- Agent status hooks
- installed skill freshness

Start with Manual permissions if you want to inspect shell/tool requests while learning the workflow. Increase autonomy only when you understand the trust boundary of your machine and worktrees.

Use Orca's Skills page / skill updater for normal skill management. Keep the official Orca skills current instead of copying their command documentation into repository `SKILL.md` files.

For this workflow, the important generic capabilities are:

- `orca-cli` — Orca-native worktree/session/browser/tool operations
- `orchestration` — Runs, tasks, workers, messages, and decision gates
- `computer-use` — native desktop UI control when needed
- `orca-emulator-android` — Android device/emulator work when needed

Only create repository-local skills for project-specific knowledge.

## 5. Finish Codex hooks

Launch Codex inside an Orca worktree. If Codex asks you to review hooks, use `/hooks`, inspect each hook, and trust only the integrations you accept, such as Ponytail or agentmemory. Start a fresh session after hook changes.

### Codex Web GPT compatibility note

Codex Web GPT owns a managed Codex `Interrupt` lifecycle hook. Other Codex hook/trust updates can cause Codex to rewrite `~/.codex/config.toml`, and Codex Web GPT intentionally fails closed if its managed fragment no longer matches its journal.

If the bridge reports an interrupt-hook inconsistency:

1. stop Codex, Orca agent sessions, and Codex Web GPT before editing anything
2. verify the bridge route with its `route status` command
3. use **Settings → Agents → Agent status hooks** to disable Orca status hooks temporarily while diagnosing if necessary
4. do not delete unrelated Orca, Ponytail, or agentmemory hook state
5. prefer a surgical repair of the bridge-owned fragment over resetting all of `~/.codex`

Do not assume Orca itself directly modified the bridge hook merely because the failure appeared after Orca setup; verify the actual config/journal mismatch first.

## 6. Finish ChatGPT Web setup

Only needed if you want a ChatGPT Web model as the parent planner/orchestrator inside Codex.

```bash
agent-harness chatgpt-web open
```

In the launcher:

1. sign in to ChatGPT
2. run the browser smoke test
3. install the Web models into Codex
4. enable Full Harness if local tools/memory are needed
5. finish the connector setup shown by the launcher
6. restart the Codex session in Orca

Keep Codex Web GPT running while using a Web model. It is transport for the parent session only; Orca still owns repository workers and worktrees.

## 7. Start agentmemory when needed

```bash
agent-harness memory start
```

Memory data stays outside the project. On Linux the default is:

```text
~/.local/share/agentmemory
```

Use memory selectively. Current repository code/tests and explicit task requirements remain authoritative.

## 8. Verify setup

```bash
agent-harness version
agent-harness doctor .
agent-harness orca doctor
agent-harness memory status
agent-harness chatgpt-web status
```

You can also inspect Orca's live orchestration guide directly when troubleshooting:

```bash
agent-harness orca guide
```

Normal users should not need that command during day-to-day work; the parent agent should load the guide when orchestration is required.

## Important: dirty working trees

New Orca worktrees start from a Git ref/commit. Uncommitted edits in another checkout are not automatically inherited.

Before starting an orchestrated task that depends on local uncommitted work:

```bash
git status --short
```

If the edits matter, commit/snapshot them first or continue from an Orca-managed worktree/branch that already contains them. Neither the parent nor a worker should silently stash, commit, or mutate the caller checkout without permission.

After setup, continue with [How to use](usage.md).
