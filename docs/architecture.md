# Agent Harness Architecture

`agent-harness` is a reusable engineering control plane for projects that use ChatGPT Web, Codex, Gemini/Antigravity, GitHub, Agent Skills, Ponytail, shared local memory, and automatic multi-agent execution.

Setup is documented in [First-time setup](first-time-setup.md). Daily operation is documented in [How to use](usage.md).

## Control and execution flow

```text
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
       │            │
       │            ├── Ponytail extension
       │            └── agentmemory adapter
       │
       ├── Ponytail plugin/hooks
       └── agentmemory plugin/MCP/hooks
                    │
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
          ┌─────────┴──────────┐
          ▼                    ▼
   durable memory       skill-maintenance
```

The intelligent orchestrator decides what work exists and who should own it. The dispatcher is deliberately deterministic: it reads a compact JSON task graph, creates isolated worktrees, schedules dependency-ready nodes, starts the selected CLI, runs declared verification, integrates successful commits, records evidence, and runs the configured final reviewer.

## Runtime plugin/extension layer

The harness installs reusable coding-host integrations rather than adding plugin setup to each task.

### Ponytail

Ponytail is installed into supported coding hosts:

- Codex plugin
- Gemini CLI extension
- Antigravity plugin

Its role is implementation discipline: prefer the smallest complete solution, reuse existing code, avoid speculative abstractions, and keep scope narrow.

Once trusted/loaded by the host, Ponytail applies to both interactive sessions and headless executor processes spawned by `agent-harness orchestrate`.

### agentmemory

agentmemory is both a local service and a host integration:

- Codex plugin + MCP/hooks
- Gemini CLI adapter
- Antigravity adapter

Its role is selective historical recall/save. Broad automatic context injection is intentionally off by default; agents query the same shared local memory only when history can materially help.

Persistent data stays outside repositories.

### Codex Web GPT

Codex Web GPT is not a Ponytail-style plugin. It is an optional launcher/model/tool bridge that lets a ChatGPT Web model operate through the local Codex tool surface and act as the intelligent orchestrator.

See [Runtime plugins and extensions](plugins.md) for the exact usage model.

## Why dispatch is deterministic

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

The dispatcher does not reinstall plugins for each node. Each subprocess uses the normal configuration of its host, so previously installed Ponytail/agentmemory integrations are available there.

## Dependency and integration model

All nodes start from the local integration branch at dispatch time. Independent nodes may run concurrently from the same snapshot. Successful commits are merged serially into the integration branch. A dependent node starts only after every declared dependency is successfully integrated, so it sees prerequisite changes.

If two parallel nodes conflict during integration, that task is marked failed and dependents are blocked. The dispatcher does not silently ask an LLM to resolve conflicts.

Runtime plans, logs, status, and summaries live under `.git/agent-harness/runs/`; temporary worktrees live outside the repository and are removed after the run unless debugging retention is requested.

## Runtime ownership

- **Codex Web GPT** owns the embedded ChatGPT browser/session and must stay running while Codex uses ChatGPT Web models or Full Harness.
- **Ponytail** is loaded by each configured coding host; the harness installs/updates it, while Codex/Gemini/Antigravity own its runtime lifecycle.
- **agentmemory** is a long-running local service plus host integration. The harness starts it detached, health-checks it, and keeps persistent data outside repositories.
- **orchestrator dispatcher** is short-lived. It creates local worktrees/branches, invokes executors, records run state, then exits.

None of these replace Codex itself. Codex remains the local tool surface used by ChatGPT Web and a primary implementation executor.

## Knowledge and behavior layers

### Git/GitHub — authoritative

Current code, tests, issue requirements, reviews, CI, and history.

### `AGENTS.md` — always-on repository behavior

Small universal engineering contract: inspect first, surgical scope, safety, verification, completion evidence. It also tells agents to follow Ponytail when available.

### Repository skills — reviewed project knowledge

Version-controlled project-specific invariants/workflows under `.agents/skills/`.

### Ponytail — reusable implementation discipline

Host plugin/extension that reinforces minimal-change/YAGNI behavior across repositories.

### Shared memory — selective historical context

agentmemory stores useful prior decisions and lessons. It is advisory and must be checked against current repository evidence.

### External skills — specialist generic expertise

Discovered on demand by `skill-discovery`. Do not preload unrelated skills.

## Token-efficiency rules

1. Recall memory only when history can materially change the task.
2. Retrieve only a few relevant memories, never the whole store.
3. Put execution context into compact task packets instead of forwarding research transcripts.
4. Load only relevant repository/external skills.
5. Do not repeat Ponytail setup/instructions in every task; rely on the installed host integration plus `AGENTS.md`.
6. Prefer deterministic verification/CI for type, lint, and test facts.
7. Save concise durable lessons only after verified work.

## Security boundaries

- Keep secrets/tokens out of memory, task plans, and executor prompts.
- Ponytail simplicity guidance must never remove auth, validation, transaction, concurrency, idempotency, data-integrity, error-handling, security, or accessibility requirements.
- Prefer Codex approval/sandbox controls; do not use dangerous bypass flags in the dispatcher.
- Gemini `yolo` is explicit opt-in; the default is `auto_edit`.
- Reviewer mutations are reverted before the final result is accepted.
- The dispatcher never pushes or merges remote branches automatically.
- Repository code/current task requirements override remembered summaries.
- Codex Web GPT is unofficial browser automation; review its security model and applicable workspace policies before enabling Full Harness.
