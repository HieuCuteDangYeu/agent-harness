# Agent Harness Architecture

`agent-harness` is a reusable engineering control plane for projects that use ChatGPT Web, Codex, Antigravity/Gemini, GitHub, repository Agent Skills, and optional shared memory.

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
                             codex-chatgpt-web
                                      │
                             local Codex harness
                    ┌─────────────────┼──────────────────┐
                    │                 │                  │
                    ▼                 ▼                  ▼
               repository          shell/tools       agent-memory
                    │                                    │
                    │                                    ▼
                    │                          TencentDB Agent Memory
                    │                          ├─ Chat Memory
                    │                          ├─ Skills
                    │                          ├─ Wiki
                    │                          └─ CodeGraph
                    │
             ┌──────┴────────┐
             ▼               ▼
          Codex          Antigravity/Gemini
       implementation      parallel/review
             │               │
             └──────┬────────┘
                    ▼
                   CI
                    │
                    ▼
             ChatGPT review
                    │
                    ▼
                  merge
                    │
          ┌─────────┴──────────┐
          ▼                    ▼
   durable memory       skill-maintenance
```

## Why Tencent Memory is a sidecar

Both TencentDB Agent Memory and `codex-chatgpt-web` can act as model proxies for Codex. They should not both own Codex's `base_url` in this harness.

This project chooses:

- `codex-chatgpt-web`: model bridge + turn-bound local tool bridge for ChatGPT Web
- TencentDB Agent Memory: shared memory/knowledge sidecar

The Tencent `:8096` proxy may be running because its upstream launcher starts all services, but the harness does not configure Codex to use it when the ChatGPT-Web bridge is active.

## Knowledge layers

### Git/GitHub — authoritative

Use for current code, tests, task requirements, reviews, CI, and historical evidence.

### `AGENTS.md` — always-on behavior

Small universal engineering contract: inspect before changing, surgical scope, safety, verification, completion evidence.

### Repository skills — reviewed procedural knowledge

Version-controlled project-specific invariants and workflows under `.agents/skills/`.

### External skills — specialist generic expertise

Discovered on demand by `skill-discovery`. Example categories include UI/UX, accessibility, security, migration, testing, and framework-specific workflows. Do not preload all of them.

### Shared memory — selective historical context

TencentDB Agent Memory stores prior decisions, failures, task outcomes, extracted skills, Wiki, and CodeGraph data. It is advisory and must be verified against the current repository.

## Token-efficiency rules

1. Search memory only when history may change the task outcome.
2. Retrieve a few relevant memories, never the whole store.
3. Keep current task context in a compact GitHub issue/task packet.
4. Load only skills relevant to the active task.
5. Prefer deterministic CI for type/lint/test facts.
6. Record concise durable lessons after verified work; do not archive noise.
7. Promote stable repeated procedure from memory into version-controlled skills.

## Security boundaries

- Keep secrets out of memory.
- Do not expose raw SQLite/Mongo administration to ChatGPT Web.
- Use the narrow `agent-memory` CLI/API operations.
- Keep Codex approval controls enabled for write/tool operations.
- `codex-chatgpt-web` is unofficial browser automation; review its security model and applicable OpenAI/workspace policies before enabling Full Harness.
- Repository code and GitHub requirements override remembered summaries.
