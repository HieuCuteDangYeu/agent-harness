# Agent Harness Architecture

`agent-harness` is a reusable engineering control plane for projects that use ChatGPT Web, Codex, Gemini/Antigravity, GitHub, Agent Skills, shared local memory, optional ChatGPT plugins, and automatic multi-agent execution.

Setup is documented in [First-time setup](first-time-setup.md). Daily operation is documented in [How to use](usage.md).

## Control and execution flow

```text
                        connected ChatGPT plugins
                 GitHub / Drive / Figma / Neon / Files
                                   │
                                   ▼
                              ChatGPT Web
                              ORCHESTRATOR
                   research / architecture / decomposition
                                   │
                        Full Harness connector
                                   ▼
                              local Codex harness
                    ┌──────────────┼───────────────┐
                    │              │               │
                    ▼              ▼               ▼
               repository      shell/tools    agentmemory MCP
                    │                              │
                    ▼                              ▼
          agent-harness orchestrate        local memory server
                    │                      REST/MCP :3111
       ┌────────────┼────────────┐           viewer   :3113
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

## Plugin layer

ChatGPT plugins/connectors are optional orchestration inputs, not harness runtime dependencies.

Use them when they provide authoritative task context or a required external action:

- GitHub — issues, PRs, CI, reviews, repository history
- Google Drive — requirements/specifications/project documents
- Figma — design inspection and design-to-code context
- Neon — PostgreSQL project/branch/schema/runtime context
- OpenAI Platform — API setup when the project actually uses the OpenAI API
- Files — project uploads or prior files stored in ChatGPT

Available plugins can vary by account/environment.

A spawned Codex/Gemini CLI executor does not automatically inherit the ChatGPT plugin session. The orchestrator must compress relevant plugin findings into the task packet: concrete requirements, IDs, paths, constraints, and acceptance criteria. It should never forward entire plugin responses when a few facts are enough.

See [Plugins and connectors](plugins.md).

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

This keeps the model focused on architecture/task decomposition while Git and deterministic checks control execution state.

## Executor boundaries

Automatic dispatch has two stable headless adapters:

- **Codex** — primary implementation/debugging executor, launched with Codex automatic-review/workspace-write behavior.
- **Gemini CLI** — parallel/test/UI-role executor. It defaults to `auto_edit`; `yolo` is explicit plan-level opt-in.

Antigravity remains useful interactively, but automatic Gemini/Antigravity-role work uses Gemini CLI because it has a headless prompt interface.

Task nodes may optionally select a model without changing scheduler semantics.

## Dependency and integration model

All nodes start from the local integration branch at dispatch time. Independent nodes may run concurrently from the same snapshot. Successful commits are merged serially into the integration branch. A dependent node starts only after every declared dependency is successfully integrated, so it sees prerequisite changes.

If two parallel nodes conflict during integration, that task is marked failed and dependents are blocked. The dispatcher does not silently ask an LLM to resolve conflicts.

Runtime plans, logs, status, and summaries live under `.git/agent-harness/runs/`; temporary worktrees live outside the repository and are removed after the run unless debugging retention is requested.

## Runtime ownership

- **Codex Web GPT** owns the embedded ChatGPT browser/session and must stay running while Codex uses ChatGPT Web models or Full Harness.
- **agentmemory** is a long-running local service. The harness starts it detached, health-checks it, and keeps persistent data outside repositories.
- **orchestrator dispatcher** is short-lived. It creates local worktrees/branches, invokes executors, records run state, then exits.
- **ChatGPT plugins** remain owned by ChatGPT. The harness does not install, authenticate, or persist their credentials.

None of these replace Codex itself. Codex remains the local tool surface used by ChatGPT Web and a primary implementation executor.

## Knowledge layers

### Git/GitHub — authoritative

Current code, tests, issue requirements, reviews, CI, and history.

### Connected project sources — task-specific authority

Drive requirements, Figma designs, Neon state, files, or another connected source when the task explicitly depends on them.

### `AGENTS.md` — always-on behavior

Small universal engineering contract: inspect first, surgical scope, safety, verification, completion evidence.

### Repository skills — reviewed procedural knowledge

Version-controlled project-specific invariants/workflows under `.agents/skills/`.

### External skills — specialist generic expertise

Discovered on demand. Do not preload unrelated skills.

### Shared memory — selective historical context

agentmemory stores useful prior decisions and lessons. It is advisory and must be checked against current repository/project evidence.

## Token-efficiency rules

1. Query only the plugin/source relevant to the active task.
2. Recall memory only when history can materially change the task.
3. Retrieve only the relevant records/sections, never whole stores or documents by default.
4. Put execution context into compact task packets instead of forwarding research/plugin transcripts.
5. Load only relevant skills.
6. Prefer deterministic verification/CI for type, lint, and test facts.
7. Save concise durable lessons only after verified work.

## Security boundaries

- Keep secrets/tokens out of memory, task plans, and executor prompts.
- Do not expose raw storage/database administration to executors unless the task explicitly requires and authorizes it.
- Prefer Codex approval/sandbox controls; do not use dangerous bypass flags in the dispatcher.
- Gemini `yolo` is explicit opt-in; the default is `auto_edit`.
- Reviewer mutations are reverted before the final result is accepted.
- The dispatcher never pushes or merges remote branches automatically.
- Repository code/current task requirements override remembered summaries.
- Plugin data can be stale; verify time-sensitive external state before acting.
- Codex Web GPT is unofficial browser automation; review its security model and applicable workspace policies before enabling Full Harness.
