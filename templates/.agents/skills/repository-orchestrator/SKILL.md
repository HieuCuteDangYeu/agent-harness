---
name: repository-orchestrator
description: Plan and execute substantial repository work through the agent-harness dispatcher. Use when the user explicitly asks for repository orchestration, multi-agent execution, or asks the harness to plan and implement a substantial task with Codex/Antigravity workers, deterministic verification, skill maintenance, and final review.
---

# Repository Orchestrator

Turn the user's request into the smallest safe implementation and execute it through the repository dispatcher.

Normal users do not create plan JSON, manage worktrees, or manually assign agents.

## Read first

Before planning:

1. read the explicit task
2. inspect current code and tests
3. read `AGENTS.md` and only relevant repository skills
4. recall agentmemory only when past decisions can materially help
5. use external research or `skill-discovery` only when needed

Authority:

```text
explicit task requirements
    > current code/tests
    > AGENTS.md + repository skills
    > agentmemory
    > general research
```

## Plan

Build a compact internal task graph. Split only at real ownership or dependency boundaries.

Default roles:

- **Codex (`codex`)** — primary implementation, backend logic, difficult debugging
- **Antigravity (`agy`)** — independent parallel work, focused tests, UI-oriented work, independent review

Use only `codex` or `agy` in the dispatcher plan. If one executor is unavailable, the dispatcher may fall back to the other.

Each task should contain only the goal, relevant paths/contracts, dependencies, acceptance criteria, constraints/non-goals, and deterministic verification commands.

## Skill maintenance

For substantial implementation, add a final `skill-maintenance` task after implementation/tests and before final review.

It may modify only `.agents/skills/` and must return one of:

- `NO_SKILL_CHANGE`
- `UPDATE_SKILL <name>`
- `CREATE_SKILL <name>`
- `REMOVE_SKILL <name>`

Do not turn one-off fixes, obvious code facts, or generic framework behavior into skills.

## Execute

If the user asked only for a plan, show the concise task graph and stop.

If implementation was requested:

1. create the schema-version-1 dispatcher plan internally
2. save it under `${TMPDIR:-/tmp}/agent-harness-plans/`
3. start it with `agent-harness orchestrate start <generated-plan.json>`
4. capture the returned run id
5. poll with `agent-harness orchestrate status <run-id>`
6. use `agent-harness orchestrate logs <run-id>` only when progress or failure needs inspection
7. after `STATUS success`, inspect the applied working-tree result and final review
8. report the result; do not push or merge remotely unless explicitly requested

Detached start snapshots the caller's current committed, modified, deleted, and untracked non-ignored files into an isolated temporary Git repository. It does not require a clean worktree and does not write caller `.git` metadata. The verified final patch is applied back to the caller worktree.

Do **not** create temporary Codex wrappers, patch harness internals inside the project, switch to foreground execution because the caller is dirty, or manually reconstruct a dirty baseline. If the dispatcher itself fails, report the concrete harness error.

Do **not** use native `create agent`, delegation, sub-agent, or ad-hoc agent tools for repository execution. The dispatcher is the only agent-launch path.

Do **not** directly edit the same implementation while a dispatcher run is active. If a run is slow, keep polling durable state. If it fails, report the concrete failure or create a new corrective dispatcher plan; never duplicate the active task as a fallback.

A timeout or Web-model disconnect is not permission to reimplement the task. The detached dispatcher continues independently.

## Runtime behavior

Ponytail and agentmemory are host integrations. Do not create setup tasks for them.

- follow Ponytail minimal-change guidance when available
- never simplify away auth, validation, transactions, concurrency/idempotency, data integrity, security, error handling, or accessibility
- let executors query shared memory selectively when useful
- save only concise, durable, verified lessons after meaningful work

If device/emulator validation is blocked by the outer sandbox (for example ADB socket access), report that limitation after completing deterministic checks that are available. Do not bypass the orchestrator to work around it.

## Final review

Before reporting success:

1. inspect the integrated diff, including skill changes
2. inspect deterministic verification results
3. confirm repository skills still match durable current behavior
4. require the configured reviewer to return `VERDICT: PASS`
5. check the result against the user's task and current repository contracts
6. report remaining risks or assumptions

Optimize for:

```text
correctness > architecture consistency > simplicity > testability > token efficiency > speed
```
