# agent-harness

A lightweight workflow, policy, and integration layer around the Orca desktop app for coding with Codex, ChatGPT Web, Antigravity (`agy`), Ponytail, and shared local memory.

**Orca GUI is the primary control plane.** Use it to open repositories, create/select worktrees, launch and watch agent sessions, inspect Runs/tasks, review diffs, manage skills, and decide what to ship. `agent-harness` should not duplicate those capabilities.

## What owns what

- **Orca** owns worktrees, multi-agent Runs/tasks, worker sessions, messages, model/effort selection, status, review surfaces, and decision gates.
- **Codex** is the default implementation/debugging/repository-analysis worker.
- **Antigravity** is useful for UI/device/visual work and independent review when it adds value.
- **Codex Web GPT** is optional parent transport only; it is not a repository worker.
- **Ponytail** supplies minimal-change/YAGNI guidance.
- **agentmemory** supplies selective historical context; current code/tests always win.
- **AGENTS.md** carries the durable workflow and safety policy that is specific to this setup.
- **Repository skills** should exist only for stable, non-obvious project-specific invariants. Generic orchestration and generic skill discovery should come from Orca/installed Agent Skills instead of being reimplemented here.

## Setup

Install the Orca desktop app first from [onorca.dev](https://www.onorca.dev/docs/install), register its CLI from **Settings → General → Orca CLI**, then run this inside the repository:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```

The harness installs its repository contract and can install Orca's version-matched `orca-cli` and `orchestration` skills. If `adb` is available it also installs `orca-emulator-android`. Prefer Orca's **Skills / Settings → Agents** UI for normal skill visibility and updates.

### Managed Markdown upgrades

`AGENTS.md` and the harness-provided `.agents/skills/*/SKILL.md` files are managed as one template set. During an upgrade, the bootstrap snapshots the previously installed templates before updating itself. If a project file still exactly matches an untouched old generated template, it is refreshed to the current version. If the project changed that file, it is preserved as project-owned content.

A historical hash catalog repairs untouched templates left stale by older harness versions whose migration logic only refreshed a subset of the managed Markdown files.

See [First-time setup](docs/first-time-setup.md) for the full GUI-first setup.

## Daily use

Start only the optional background integrations you need:

```bash
agent-harness memory start
agent-harness chatgpt-web open   # only when using a ChatGPT Web model
```

Then open **Orca GUI**, select the repository/worktree, and launch the parent Codex session there. For a substantial or explicitly multi-agent task, ask naturally:

```text
Implement this using Orca orchestration.
Follow AGENTS.md.
Use the smallest useful task graph.
Use Codex as the primary worker and Antigravity where it adds value.
Run meaningful verification and an independent final review.
Deliver only on PASS.
Do not push, open a PR, or merge remotely unless I explicitly ask.
```

For a small focused task:

```text
Implement this directly.
Follow AGENTS.md.
Do not orchestrate unless splitting the task materially helps.
Run targeted verification and review the diff.
```

The agent should use Orca's installed `orchestration` skill and load Orca's live, version-matched guide before mutating Run/task state. The user can stay in the Orca GUI for monitoring and review.

## Skills

Use Orca's Skills page, skill picker, and built-in skill discovery/Find Skills surface when available. Prefer an existing maintained skill over writing a generic local `SKILL.md`.

Create or keep `.agents/skills/...` only when the knowledge is specific to the repository and materially changes future engineering decisions, such as authentication invariants, event-delivery rules, persistence ownership, or release procedures.

The harness-provided generic skill files are compatibility/policy shims, not a competing capability layer.

## Docs

- [First-time setup](docs/first-time-setup.md)
- [How to use](docs/usage.md)
- [Architecture](docs/architecture.md)
