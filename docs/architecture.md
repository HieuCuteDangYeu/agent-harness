# Agent Harness Architecture

`agent-harness` is a reusable engineering control plane for projects that use ChatGPT Web, Codex, Antigravity/Gemini, GitHub, repository Agent Skills, and shared local memory.

This document explains **why the components are arranged this way**. It intentionally does not define another installation method. For setup and daily use, follow [one-command-setup.md](one-command-setup.md).

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
                              Codex Web GPT
                           launcher must be running
                                      │
                             local Codex harness
                    ┌─────────────────┼──────────────────┐
                    │                 │                  │
                    ▼                 ▼                  ▼
               repository          shell/tools      agentmemory MCP
                                                         │
                                                         ▼
                                               local memory server
                                               REST/MCP :3111
                                               viewer   :3113
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

## Runtime ownership

Two local runtimes need different lifecycle behavior:

- **Codex Web GPT** owns the embedded ChatGPT browser/session and must stay running while Codex uses ChatGPT Web models or Full Harness. The harness exposes `chatgpt-web status/open/repair` instead of asking users to remember upstream launcher commands.
- **agentmemory** is a long-running server. Upstream's default command runs in the foreground, so the harness starts it detached, records a runtime log/PID, health-checks it, and exposes `memory start/status/stop/restart/logs/viewer/doctor/upgrade`.

Neither runtime replaces Codex itself. Codex remains the local coding harness; these are supporting services around it.

## Why agentmemory fits this harness

`agentmemory` is used as an MCP/REST memory service rather than as a model proxy. That avoids any conflict with Codex Web GPT, which remains responsible for the ChatGPT-Web model bridge and Full Harness tool bridge.

All connected local agents can share the same memory server. The harness wires supported adapters for Codex, Gemini CLI, and Antigravity when those hosts are detected.

## Keyless-by-default memory

The harness deliberately avoids requiring another paid LLM API account.

Default configuration:

```text
BM25 recall                  on
local MiniLM embeddings      on
cloud LLM provider           none required
LLM observation compression  off
automatic context injection  off
MCP tool set                 core (8 tools)
```

This preserves useful semantic recall without making memory dependent on ChatGPT/Gemini API billing.

## Knowledge layers

### Git/GitHub — authoritative

Use for current code, tests, task requirements, reviews, CI, and historical evidence.

### `AGENTS.md` — always-on behavior

Small universal engineering contract: inspect before changing, surgical scope, safety, verification, completion evidence.

### Repository skills — reviewed procedural knowledge

Version-controlled project-specific invariants and workflows under `.agents/skills/`.

### External skills — specialist generic expertise

Discovered on demand by `skill-discovery`. Do not preload unrelated skills.

### Shared memory — selective historical context

agentmemory stores useful prior engineering context and lessons. It is advisory and must be checked against the current repository.

## Token-efficiency rules

1. Search memory only when history can materially change the task outcome.
2. Retrieve a few relevant memories, never the whole store.
3. Prefer `memory_smart_search` / `memory_recall` over broad automatic context injection.
4. Keep the current task in a compact GitHub issue/task packet.
5. Load only skills relevant to the active task.
6. Prefer deterministic CI for type/lint/test facts.
7. Save concise durable lessons after verified work; do not archive noise.
8. Promote stable repeated procedures from memory into version-controlled skills.

## Security boundaries

- Keep secrets, API keys, passwords, and tokens out of memory.
- Do not expose raw storage administration to ChatGPT Web.
- Keep Codex approval controls enabled for write/tool operations.
- Codex Web GPT is unofficial browser automation; review its security model and applicable OpenAI/workspace policies before enabling Full Harness.
- Repository code and current GitHub requirements override remembered summaries.
