# agent-harness

A reusable **project boilerplate + installer**, not a second orchestration
system. `templates/` contains what gets installed into target projects;
`docs/` documents this harness repository and is **never installed**.

| Responsibility | Source of truth |
| --- | --- |
| Agent sessions, worktrees, Runs, task gates | Orca + its official `orca-cli` and `orchestration` skills |
| Desktop, device, Linear, workspace tooling | Relevant official Orca skills, loaded only when needed |
| Small changes, YAGNI, optional diff review | Official [Ponytail](https://github.com/DietrichGebert/ponytail) plugin |
| Cross-session recall and captured lessons | Official [agentmemory](https://github.com/rohitg00/agentmemory) integration |
| Verified project learning | Installed `.agents/skills/project-learning/SKILL.md` (on demand) |
| Project-specific architectural invariants | Project-owned `.agents/skills/<name>/SKILL.md`, only when justified |
| Difficulty/effort/worker selection | Short `AGENTS.md` rules; optional `agent-harness route` advisory tool |

## Install

Install [Orca](https://www.onorca.dev/docs/install), register its CLI in
Settings, and run inside a project's Git checkout:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

The normal `ready` flow installs/updates **`templates/AGENTS.md`** and
**`templates/.agents/skills/project-learning/SKILL.md`** into the target
repository. It also installs Orca's official `orca-cli`, `orchestration`,
and `computer-use` skills when Orca is available; Android installation
is conditional on `adb`. No generic Orca/Ponytail/agentmemory prompts
are duplicated in the project.

Optional integrations (run interactively and review the hooks requested):

```bash
agent-harness ready . --with-ponytail
agent-harness ready . --with-agentmemory
agent-harness memory connect claude-code --with-hooks   # only if no native memory plugin hooks
```

`--with-agentmemory` asks separately before enabling automatic session/event
capture. To avoid double-capture, Codex uses its native agentmemory plugin
**or** the MCP-only connector, not both sets of hooks.

## Skills and memory stay current

Use Orca's **Skills → Update** UI for built-in skills, or its version-matched
CLI:

```bash
agent-harness orca update                   # official Orca updater
agent-harness orca auto-update enable       # optional Linux user timer, daily
agent-harness orca auto-update status
agent-harness orca auto-update disable
```

The daily timer is **off by default** and touches only **already installed
Orca skills**. It doesn't update Ponytail plugins, agentmemory binaries, or
project-authored skills. For those, use each upstream host/plugin updater
and review changes. Automatic learning comes from supported **agentmemory
capture hooks** after explicit opt-in. The installed `project-learning`
skill conditionally promotes **verified** lessons into memory or a
reviewable project-owned skill update rather than rewriting generic
prompts after every task.

## Work

Start any configured agent in Orca. Small tasks stay in the parent session;
complex tasks may use specialized Orca workers with supported reasoning levels,
quota headroom, and independent verification. Current code/tests override
stored memory. Projects remain unpushed unless shipping was authorized.

For provider-neutral advisory routing, see [routing](docs/routing.md); it needs
an actual fresh Orca Usage snapshot and never pretends it has a live quota API.

## Guides

- [Skills and memory ownership](docs/skills-memory.md)
- [First-time setup](docs/first-time-setup.md)
- [Everyday use](docs/usage.md)
- [Architecture](docs/architecture.md)
- [Safe upgrade/migration](docs/migration.md)
