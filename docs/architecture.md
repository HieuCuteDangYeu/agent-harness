# Agent Harness Architecture

`agent-harness` is a reusable engineering control plane for projects that use ChatGPT Web, Codex, Gemini/Antigravity, GitHub, Agent Skills, and shared local memory.

This document explains **why the components are arranged this way**. Setup remains exclusively in [one-command-setup.md](one-command-setup.md).

## Control and execution flow

```text
                                   GitHub
                          source of truth / task state
                    repo + issues + PRs + CI + history
                                      │
                                      ▼
                              ChatGPT Web
                              ORCHESTRATOR
                   research / architecture / decomposition
                                      │
                           Full Harness connector
                                      ▼
                              local Codex harness
                    ┌─────────────────┼──────────────────┐
                    │                 │                  │
                    ▼                 ▼                  ▼
               repository          shell/tools      agentmemory MCP
                    │                                    │
                    ▼                                    ▼
          agent-harness orchestrate               local memory server
                    │                              REST/MCP :3111
       ┌────────────┼────────────┐                  viewer   :3113
       ▼            ▼            ▼
  Codex tasks   Gemini tasks  dependency scheduler
       │            │            │
       └────────────┴─────┬──────┘
                          ▼
                  local integration branch
                          │
                  deterministic verification
                          │
                          ▼
                     final reviewer
                          │
                          ▼
                     human/GitHub review
                          │
                          ▼
                         merge
                          │
               ┌──────────┴──────────┐
               ▼                     ▼
        durable memory        skill-maintenance
```

The intelligent orchestrator decides what work exists and who should own it. The dispatcher is deliberately deterministic: it reads a compact JSON task graph, creates isolated worktrees, schedules dependency-ready nodes, starts the selected CLI, runs declared verification, integrates successful commits, records evidence, and runs the configured final reviewer.

## Why dispatch is a deterministic harness feature

The LLM should not manually juggle terminal sessions or invent ad-hoc coordination. The execution engine owns the mechanical parts:

- one worktree per task
- explicit dependency edges
- bounded parallelism
- task-level logs and last messages
- verification commands outside the agent's self-report
- automatic commits for successful uncommitted changes
- integration conflict detection
- downstream blocking after failures
- final review with an explicit `PASS` / `BLOCK` verdict
- local integration only; no surprise push/merge

This keeps the model focused on architecture and task decomposition while Git and deterministic checks control execution state.

## Executor boundaries

Automatic dispatch currently has two stable headless adapters:

- **Codex** — primary implementation/debugging executor, launched with Codex automatic-review/workspace-write behavior.
- **Gemini CLI** — parallel/test/UI-role executor. It defaults to `auto_edit`; `yolo` is explicit plan-level opt-in.

Antigravity remains useful interactively, but the automatic Gemini/Antigravity role uses Gemini CLI because it has a documented headless prompt interface.

Task nodes may optionally select a model. That lets a Codex executor use an installed model route without changing scheduler semantics.

## Dependency and integration model

All nodes start from the local integration branch at dispatch time. Independent nodes may run concurrently from the same snapshot. On success their commits are merged serially into the integration branch. A dependent node starts only after every declared dependency is successfully integrated, so it sees prerequisite changes.

If two parallel nodes conflict during integration, that node is marked failed and any dependent nodes are blocked. The dispatcher does not attempt an LLM-authored conflict resolution silently.

Runtime plans, logs, status, and summaries live under `.git/agent-harness/runs/`; temporary worktrees live outside the repository and are removed after the run unless debugging retention is requested.

## Runtime ownership

- **Codex Web GPT** owns the embedded ChatGPT browser/session and must stay running while Codex uses ChatGPT Web models or Full Harness.
- **agentmemory** is a long-running local service. The harness starts it detached, health-checks it, and keeps persistent data outside repositories.
- **orchestrator dispatcher** is short-lived. It creates local worktrees/branches, invokes executors, records run state, then exits.

None of these replace Codex itself. Codex remains the local tool surface used by ChatGPT Web and a primary implementation executor.

## Knowledge layers

### Git/GitHub — authoritative

Current code, tests, issue requirements, reviews, CI, and history.

### `AGENTS.md` — always-on behavior

Small universal engineering contract: inspect first, surgical scope, safety, verification, completion evidence.

### Repository skills — reviewed procedural knowledge

Version-controlled project-specific invariants/workflows under `.agents/skills/`.

### External skills — specialist generic expertise

Discovered on demand. Do not preload unrelated skills.

### Shared memory — selective historical context

agentmemory stores useful prior decisions and lessons. It is advisory and must be checked against current repository evidence.

## Token-efficiency rules

1. Recall memory only when history can materially change the task.
2. Retrieve a few relevant memories, never the whole store.
3. Put execution context into compact task packets instead of forwarding research transcripts.
4. Load only relevant skills.
5. Prefer deterministic verification/CI for type, lint, and test facts.
6. Save concise durable lessons only after verified work.

## Security boundaries

- Keep secrets/tokens out of memory and task plans.
- Do not expose raw storage administration to ChatGPT Web.
- Prefer Codex's approval/sandbox controls; do not use dangerous bypass flags in the dispatcher.
- Gemini `yolo` is explicit opt-in; the default is `auto_edit`.
- Reviewer mutations are reverted before the final result is accepted.
- The dispatcher never pushes or merges remote branches automatically.
- Repository code/current GitHub requirements override remembered summaries.
- Codex Web GPT is unofficial browser automation; review its security model and applicable workspace policies before enabling Full Harness.
