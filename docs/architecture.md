# Architecture: one controller, one prompt

```text
Orca GUI / any enabled parent CLI
   |
   +-- project AGENTS.md: short triage, safety and evidence contract
   |
   +-- existing session (normal small tasks / native subagents)
   |           |
   |           +-- native Ponytail quality rules, if installed
   |           +-- relevant memory from agentmemory, if connected
   |
   +-- Orca orchestration skill (when supervised workers help)
               |
               +-- agent/model selection (capability, effort, quota)
               +-- Orca Runs, worktrees, worker sessions and gates
               +-- native review and verification
   |
   +-- validated lessons -> agentmemory (with opt-in hooks)
   +-- durable project invariant -> reviewed project skill (rare)
```

## Ownership boundaries

Orca manages agent sessions, worktrees, terminal operations, Runs,
dependencies, messages, gates, and its own skills. Never maintain a
second task DAG, host runner, or copy of its live guides.

Ponytail is an optional provider-host plugin for compact implementation
and code review. Do not duplicate its prompt in AGENTS.md or a generated
repository skill.

agentmemory is an optional local history system. Its MCP and capture
hooks are configured through upstream integration paths. Orca's agent
status hooks are separate, and native hooks from multiple integrations
must not be duplicated for the same event.

The harness installs a short project `AGENTS.md` and one conditional
`project-learning` skill from `templates/`. It also provides optional
integration setup and a quota-based routing advisory helper
that does not dispatch agents. It does **not** pretend a manually
recorded quota is live data.

## Skill lifecycle

Official Orca skills: installed by Orca; updated through Orca UI or CLI;
optional off-by-default Linux timer calls Orca's updater.

Ponytail: updated via the agent host's plugin marketplace/extension flow;
the harness doesn't vendor or replace it.

agentmemory: session/event capture can be automatic after opt-in;
software upgrades are explicit because the runtime and data may change.
The installed `project-learning` skill enables promoting verified lessons
into memory or reviewed project-specific skills when warranted, with
current code/tests as evidence. Internal `docs/` never deploy into projects.

See [skills and memory](skills-memory.md) and [routing](routing.md).
