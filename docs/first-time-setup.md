# First-time setup

1. Install [Orca](https://www.onorca.dev/docs/install) and register
   its CLI from Settings. Review available coding agents, permissions,
   model/effort controls, usage pools, and repository worktrees.
2. In a project checkout, run the [bootstrap command](../README.md#install).
   It creates a short `AGENTS.md`, installs the version-matched Orca core
   skills (`orca-cli`, `orchestration`, `computer-use`), and installs
   the Android emulator skill when `adb` is available.
3. Optional integrations: `agent-harness ready . --with-ponytail` and
   `agent-harness ready . --with-agentmemory`. The latter prompts
   separately for **local session/event capture**. Inspect and trust
   host hooks before relying on them.
4. To keep official Orca skills current, use the in-app updater or
   `agent-harness orca update`. For an **opt-in** daily Linux systemd
   user timer run `agent-harness orca auto-update enable`. This does
   not update Ponytail, agentmemory runtimes, or project-authored skills.
5. Verify `agent-harness doctor .`, `agent-harness orca doctor`,
   `agent-harness memory status` (if installed), and the agentmemory
   viewer after a test session if capture was enabled.

For Claude Code, enable the upstream Ponytail plugin through its
interactive `/plugin` commands, then enable auto-update in its
marketplace UI if wanted. For other agents inspect the official
[Ponytail install guide](https://github.com/DietrichGebert/ponytail/blob/main/INSTALL.md).
For additional memory clients use `agent-harness memory connect <agent>`;
add `--with-hooks` only if the agent does **not** already have a native
agentmemory plugin's hooks.

The harness never overwrites modified project prompts or skills.
Untouched obsolete generated generic skills are removed during upgrade
using exact historical hashes; customized files remain untouched.
See [migration](migration.md) and [skill ownership](skills-memory.md).

## Security

Some Orca agent launch defaults allow broad permissions. Inspect
Settings → Agents and use manual approvals where appropriate.
An agent worktree is **not** a sandbox for all host credentials.

The retired browser bridge is not installed or changed. All agent
execution is through Orca-supported CLI integrations.
