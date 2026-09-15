# How to use agent-harness

Use this after [First-time setup](first-time-setup.md).

The normal workflow is **Orca GUI first**. The harness prepares policy and integrations; Orca is where you create/select worktrees, launch agents, monitor Runs, inspect diffs, review output, and decide what to ship.

## Start the optional integrations

From the repository checkout, start only what you need:

```bash
agent-harness memory start
agent-harness chatgpt-web open   # only for ChatGPT Web models
```

Then open the Orca desktop app yourself. You do not need `agent-harness orca open` for normal use.

In Orca:

1. select the repository
2. create or open the intended worktree
3. launch a Codex parent session there
4. if using Codex Web GPT, select the Web model for that parent session
5. keep Orca's Agents/Run/diff surfaces visible for supervision and review

Ponytail and agentmemory load through the coding agents. Orca owns the multi-agent execution surface.

## Small focused task

For a change that does not benefit from multiple workers, use one session directly:

```text
Implement this directly.
Follow AGENTS.md.
Do not orchestrate unless splitting the task materially helps.
Run the narrowest meaningful verification and review the diff.
Do not push, open a PR, or merge remotely unless I explicitly ask.
```

A single-agent task should stay single-agent. Do not create a Run just because orchestration exists.

## Substantial or multi-agent task

Ask naturally:

```text
Implement this using Orca orchestration.
Follow AGENTS.md.
Use the smallest useful task graph.
Use Codex as the primary implementation/debugging worker.
Use Antigravity when UI, device, visual verification, or independent review would benefit.
Run meaningful verification and an independent final review.
Deliver only on PASS.
Do not push, open a PR, or merge remotely unless I explicitly ask.
```

The parent should use Orca's installed `orchestration` skill and load Orca's live, version-matched orchestration guide before mutating Run/task state.

The intended flow is:

```text
you in Orca GUI
        ↓
parent Codex / ChatGPT Web session
        ↓
AGENTS.md workflow policy
        ↓
Orca official orchestration skill
        ↓
Orca Run
 ├─ implementation task(s)
 ├─ verification task(s)
 └─ independent review task
        ↓
PASS / BLOCK decision gate
        ↓
review integrated diff in Orca GUI
        ↓
ship only when explicitly desired
```

Orca owns the Run, dependencies, worktrees, worker sessions, messages/recovery, model/effort settings, progress, and decision gates. `agent-harness` must not create a second orchestration DAG underneath it.

## Use the Orca GUI as the human control plane

Prefer the GUI for:

- creating and selecting worktrees
- choosing Codex or Antigravity
- watching several sessions side by side
- inspecting agent activity / Run progress
- reviewing diffs and annotations
- checking workspace status/checkpoints
- installing/updating skills
- approving commit/push/PR actions

The CLI is still useful to agents for version-matched guides and typed automation. The human does not need to mirror every GUI action with a terminal command.

## Worker selection

Use workers because they add a real boundary, not just to increase agent count.

- **Codex**: default implementation, debugging, repository analysis, tests, backend work, code review.
- **Antigravity**: UI/device/visual work, emulator-oriented tasks, focused implementation, or independent review when useful.
- **Other Orca-supported agents**: only when the task materially benefits from them.

Do not launch duplicate sibling workers on the same implementation unless competing approaches were explicitly requested. The parent must not directly implement the same task while an Orca worker owns it.

For substantial work, the default graph should be approximately:

```text
implementation -> verification -> independent review -> PASS/BLOCK gate
```

Split further only at real ownership or dependency boundaries.

## Plan only

```text
Plan this using Orca orchestration.
Follow AGENTS.md.
Do not execute the Run yet.
```

After reviewing the plan in Orca:

```text
Approved. Execute the plan in Orca.
```

## Models and reasoning effort

Use Orca's GUI/session controls for model and reasoning-effort choices when available. For orchestrated workers, let the official orchestration skill use Orca's current supported model/effort surface.

Do not hard-code model IDs or effort values into repository skills just because one current session accepts them.

## Skills: use Orca first

Do not create a generic repository skill for functionality Orca or the installed Agent Skills ecosystem already provides.

Use, in order:

1. Orca's Skills page and installed skills
2. the agent's discovered skill picker (`/` / `$` depending on the agent)
3. Orca's built-in skill discovery / Find Skills surface when available
4. a maintained external skill with inspectable provenance
5. a repository-local skill only for stable project-specific knowledge

Good repository-local skill candidates include:

- authentication/authorization invariants unique to the project
- service ownership boundaries
- event/outbox/idempotency rules
- persistence conventions
- media-processing workflows
- deployment/release procedures unique to the repository

Do not create local skills for generic TypeScript, NestJS, React Native, testing, orchestration, or skill discovery when a maintained skill already covers them.

## Android / device work

For Android tasks, use Orca's `orca-emulator-android` skill when installed and let the worker use the adb-connected device/emulator workflow.

A good prompt is:

```text
Implement this using Orca orchestration.
Use the Android Orca skill for ADB/device verification.
Use Antigravity for visual/device testing when useful.
Require verification and final review before PASS.
```

Device access is a host capability. Never claim ADB/device verification if the selected Orca host/session cannot see the device.

## Desktop / visual workflows

Use Orca's `computer-use` skill when the task requires operating native desktop apps. Use Orca's built-in browser/design surfaces for web UI inspection when they are the better fit.

## Dirty working tree

A newly-created Orca worktree is based on a Git ref/commit. It does not automatically receive unrelated uncommitted edits from another checkout.

Before a Run depends on local edits:

```bash
git status --short
```

If those edits matter, commit/snapshot them first or work from an Orca-managed worktree/branch that already contains them. Agents must not silently stash or commit the caller checkout.

## Memory

Use agentmemory only when prior decisions, failures, or accepted architecture materially help the task.

Priority remains:

```text
explicit task requirements
    > current repository code/tests
    > AGENTS.md + repository-specific skills
    > agentmemory
    > external/general research
```

Save only concise verified lessons that future agents are likely to reuse. Do not dump transcripts, raw logs, or secrets into memory.

## Verification and final review

Run the narrowest meaningful checks first, then broader checks only when required:

1. relevant tests
2. typecheck
3. lint
4. integration tests
5. broader suites when necessary

For substantial Orca Runs, verification and final review should be explicit tasks rather than trusting an implementation worker's self-report.

A failed required check blocks PASS.

## Remote operations

By default, delivery stays local. Do not push, create a remote PR, or merge unless the user explicitly asks.

When the user does ask to ship, prefer Orca's GUI diff/commit/push/PR surfaces so the human can inspect the final integrated result.

## Troubleshooting

Use these only when needed:

```bash
agent-harness orca status
agent-harness orca doctor
agent-harness doctor .
agent-harness memory status
agent-harness chatgpt-web status
```

To inspect the live orchestration protocol Orca currently exposes:

```bash
agent-harness orca guide
```

Do not use the removed `agent-harness orchestrate ...` or custom `agent-harness agy ...` runtimes. Orca is the sole task-level orchestration owner.
