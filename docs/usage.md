# Everyday use

1. Open a project in Orca and choose **any configured CLI agent**.
2. Ask normally. Trivial/easy work stays in this session; moderate work
   usually stays here too. Use native subagents for useful local decomposition.
3. For supervised workers, use the installed Orca `orchestration` skill
   and **load the live guide** (`agent-harness orca guide`). Use the
   `orca-cli` skill for ordinary terminals, browser and worktrees.
4. Match worker capability to the task, check supported model/reasoning
   effort and actual account/model-group quotas, then verify outcomes.
   The optional `agent-harness route` CLI is advisory only.
5. Keep tests and current code authoritative. Do not ship remotely
   without authorization.

Ponytail supplies minimal-change and review guidance **when its upstream
plugin is installed**; no project rule copy is needed.

agentmemory supplies cross-session recall **when connected**. Optional
native hooks record sessions; retrieve narrowly and save/promote only
durable verified lessons. Do not turn every finished task into a new
repository skill. For a stable project-specific invariant, update a
project-owned skill through a reviewed diff.

Useful diagnostics and updates:

```bash
agent-harness doctor .
agent-harness orca doctor
agent-harness orca update
agent-harness orca auto-update status
agent-harness memory status
agent-harness memory viewer
```

See [skills/memory](skills-memory.md), [routing](routing.md), and
[setup](first-time-setup.md) for plugin-specific configuration.
