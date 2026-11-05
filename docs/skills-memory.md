# Skills, Ponytail, and memory: harness integration reference

> This file documents **agent-harness itself**. It is never installed in
> target projects. Runtime instructions belong in `templates/AGENTS.md`
> and `templates/.agents/skills/project-learning/SKILL.md`.

This harness deliberately does **not** vendor public skill prompts or
implement its own agent runner. Orca already ships version-matched skills
and a native updater; third-party plugins own their own hooks and releases.

## Orca's official skill catalog

| Skill | When to load | Harness behavior |
| --- | --- | --- |
| `orca-cli` | Worktrees, terminals, browser, files, automation | Installed at setup; read the live guide when needed |
| `orchestration` | Supervised Runs, worker dispatch, DAGs, messages, gates | Installed at setup; always load full live guide before mutation |
| `computer-use` | Desktop accessibility and UI actions | Installed at setup; activate on demand |
| `orca-emulator-android` | Android emulator and device via adb | Installed when `adb` is available |
| `orca-emulator` | iOS Simulator | Install on capable hosts, on demand |
| `orca-linear` | Linear tickets | Install only for Linear projects |
| `orca-per-workspace-env` | Workspace recipes (`orca.yaml`) | Install only for environment tasks |

Reference: [Official Orca skill registry](https://www.onorca.dev/docs/cli/skills).
Skills are short discovery stubs; their live guides come from the installed
Orca CLI, e.g. `orca skills get orchestration --full`. Don't duplicate the
guide's CLI options into `AGENTS.md`. Orca's skills also already cover
generic discovery, multi-agent handoff, worktrees, device access, and updates.

For terminal/worktree operations use `orca-cli`. Use `orchestration` only
when a supervised worker/task graph is needed. Prefer the parent session
or native subagents for smaller tasks; Orca workers add value for a
different provider, separate workspace, or tracked gate.

## Skill updates

Orca exposes skill freshness and a background update workflow in its
**Skills** UI; it also provides `orca skills update --all`, which
updates *already installed* skills. Prefer the GUI when reviewing versions.

An **opt-in** Linux user systemd timer can call Orca's official updater
once per day, with a randomized delay:

```bash
agent-harness orca auto-update enable
agent-harness orca auto-update status
agent-harness orca auto-update disable
```

This does not install additional skills or bypass third-party review.
The timer is disabled by default and needs a functioning user systemd
session. Setup records the verified Orca CLI path and the current PATH
(including an nvm-managed Node installation); rerun `enable` if those
paths change. Inspect failures with
`journalctl --user -u agent-harness-orca-skills.service`.
On other operating systems use Orca's updater directly.
Pinned/customized skills may be skipped by Orca; inspect its update results.

Ponytail is installed as an **upstream host plugin**. Its own rules,
review commands, and hook behavior are not copied into our project
contract. Supported installers in the harness cover detected Codex,
Antigravity, Gemini, OpenCode, Copilot, and Pi. Claude Code uses the
upstream interactive `/plugin` commands; you can enable its marketplace
auto-update in the Plugin UI. Other providers can follow
[Ponytail's official INSTALL.md](https://github.com/DietrichGebert/ponytail/blob/main/INSTALL.md).
There is no safe, universal third-party plugin update command.

## Memory: capture is not policy

[agentmemory](https://github.com/rohitg00/agentmemory) can persist
history across agent sessions via MCP and **native lifecycle hooks**.
It is separate from Orca's hook status reporting and `AGENTS.md` files.

- The local daemon stores memory outside each Git repository, in the
  persistent data directory printed by `agent-harness memory data-dir`.
- `agent-harness ready . --with-agentmemory` asks for permission before
  enabling automatic capture. Hooks may record prompts, tool results, and
  other session content. Review secret scrubbing and retention settings.
- For Codex use the official plugin's MCP plus its native hooks **once**.
  Don't simultaneously use `agentmemory connect codex --with-hooks`.
- For Antigravity CLI, `agentmemory connect antigravity-cli --with-hooks`
  enables native capture; without that flag it connects MCP only.
- Other agents can use `agent-harness memory connect <agent> [--with-hooks]`
  with an upstream-supported adapter; check for a preinstalled plugin
  first to avoid duplicate hook registration.
- Confirm capture in the agentmemory viewer. A successful MCP connection
  alone does **not** prove events are being saved.

Use memory to recover **relevant, verified** prior decisions, root causes,
and outcomes. Never treat it as authoritative over code/tests. Avoid putting
credentials, personal information, or unrelated project data in prompts
or handoffs. The agent should not blindly store every transcript as a
trusted long-term architectural rule.

## Automatic improvement without prompt bloat

The on-demand **`project-learning` skill is distributed to projects**
by `agent-harness init` from `templates/.agents/skills/`. It describes
when to retrieve past decisions, store verified lessons, and make a
reviewable change to an existing or new project-specific skill.

Capture hooks are optional and do not by themselves validate lessons.
The skill uses upstream integrations rather than implementing a competing
memory backend or an always-running skill generator. Ordinary edits
create neither a new memory nor a skill. The integration contract itself
lives in the boilerplate, not this documentation file.

This avoids a cycle where generated prompt files grow and contradict
upstream updates. There is no autonomous "skill authoring" daemon.

## Upgrades vs memory data

Updating Orca skills is different from upgrading agentmemory's runtime.
`agent-harness memory upgrade` is explicit and may change dependencies
or data format; back up memory and review upstream notes first. The
daily Orca timer never updates agentmemory, Ponytail, or project skills.

## Practical boundaries

- Don't invent a live Orca quota API; use the Usage UI or fresh verified
  snapshot for advisory ranking.
- Don't enable high-trust permissions or execute third-party hooks without
  reviewing their source and trust prompts.
- Don't let an installed skill overwrite project-specific code/tests or
  a customized prompt.
