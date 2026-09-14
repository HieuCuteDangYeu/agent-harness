---
name: repository-orchestrator
description: Plan and execute substantial repository work through the agent-harness dispatcher. Use when the user explicitly asks for repository orchestration, multi-agent execution, or asks the harness to plan and implement a substantial task with Codex/Gemini workers, deterministic verification, skill maintenance, and final review.
---

# Repository Orchestrator

Turn the user's request into the smallest safe implementation and execute it through the repository dispatcher.

Normal users should not create plan JSON, manage worktrees, or manually assign agents.

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

Memory is advisory. Verify remembered facts against the current repository.

## Plan

Build a compact internal task graph. Split only at real ownership or dependency boundaries.

Default roles:

- **Codex** — primary implementation, backend logic, difficult debugging
- **Gemini** — independent parallel work, focused tests, UI-oriented work, independent review

Do not assign both agents to the same change unless alternatives were explicitly requested.

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
2. save it under `.git/agent-harness/plans/`
3. start it with `agent-harness orchestrate start <generated-plan.json>`
4. capture the returned run id
5. poll with `agent-harness orchestrate status <run-id>`
6. use `agent-harness orchestrate logs <run-id>` only when progress or failure needs inspection
7. after `STATUS success`, inspect the integration branch and final result
8. report the result; do not push or merge remotely unless explicitly requested

Do **not** use native `create agent`, delegation, sub-agent, or ad-hoc agent tools for repository execution. The dispatcher is the only agent-launch path.

Do **not** directly edit the same implementation while a dispatcher run is active. If a run is slow, keep polling durable state. If it fails, report the concrete failure or create a new corrective dispatcher plan; never duplicate the active task as a fallback.

A timeout in the orchestrator's command view is not permission to reimplement the task itself. The detached dispatcher survives bounded shell/tool waits.

Example order:

```text
implementation / tests
        ↓
skill-maintenance
        ↓
final reviewer
```

## Runtime behavior

Ponytail and agentmemory are host integrations. Do not create setup tasks for them.

- follow Ponytail minimal-change guidance when available
- never simplify away auth, validation, transactions, concurrency/idempotency, data integrity, security, error handling, or accessibility
- let executors query shared memory selectively when useful
- save only concise, durable, verified lessons after meaningful work

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
