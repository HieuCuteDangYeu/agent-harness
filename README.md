# agent-harness

Reusable, framework-agnostic engineering harness for orchestrating ChatGPT Web, Codex, Antigravity/Gemini, repository Agent Skills, GitHub Issues/PRs, Ponytail, optional TencentDB Agent Memory, and deterministic CI.

The goal is simple: **one command per project to prepare the engineering harness, then let agents reuse repository knowledge instead of repeatedly re-learning it.**

## Architecture

```text
                                   GitHub
                          source of truth / task state
                                      │
                                      ▼
                              ChatGPT Web
                              ORCHESTRATOR
                                      │
                           Full Harness connector
                                      ▼
                             codex-chatgpt-web
                                      │
                                  Codex
                    ┌─────────────────┼──────────────────┐
                    │                 │                  │
                    ▼                 ▼                  ▼
               repository          local tools       agent-memory
                                                           │
                                                           ▼
                                                 TencentDB Agent Memory
                                                 memory / skills / wiki /
                                                 code graph

                         Codex + Antigravity/Gemini
                                  │
                                  ▼
                             GitHub Actions
                                  │
                                  ▼
                            ChatGPT review
```

See [docs/architecture.md](docs/architecture.md) for the full model.

## Install once

```bash
mkdir -p ~/.local/share ~/.local/bin

git clone \
  git@github.com:HieuCuteDangYeu/agent-harness.git \
  ~/.local/share/agent-harness

ln -sf \
  ~/.local/share/agent-harness/bin/agent-harness \
  ~/.local/bin/agent-harness
```

Ensure `~/.local/bin` is on `PATH`.

## Prepare any project in one command

Inside an existing Git repository:

```bash
agent-harness ready .
```

This is the recommended entry point.

It:

- installs the non-destructive project harness
- installs `AGENTS.md` + meta-skills
- installs the safe `agent-memory` CLI
- detects Codex / Antigravity / Gemini / Docker
- optionally installs Ponytail
- optionally installs `codex-chatgpt-web`
- optionally provisions TencentDB Agent Memory with Docker
- runs a readiness report
- prints the few one-time account/credential steps that cannot be safely automated

Read [docs/one-command-setup.md](docs/one-command-setup.md) for details.

### Core-only mode

For CI or when you only want repository files:

```bash
agent-harness ready . --core-only --non-interactive
```

Other flags:

```text
--yes
--skip-ponytail
--skip-chatgpt-web
--skip-memory
--non-interactive
```

## Important integration choice

TencentDB Agent Memory and `codex-chatgpt-web` can both act as model proxies. This harness **does not stack them as competing Codex model providers**.

The architecture is:

```text
codex-chatgpt-web -> ChatGPT Web model/tool bridge
TencentDB Agent Memory -> local memory/knowledge sidecar
```

Tencent's `:8096` proxy may be running because its official deployment starts the full stack, but **do not point Codex at that proxy when `codex-chatgpt-web` owns the Codex model route**.

ChatGPT Web reaches memory through the Codex Full Harness tool surface and the narrow `agent-memory` helper rather than raw DB access.

## Project files installed

```text
project/
├── AGENTS.md
├── .agent-harness-version
├── .agents/
│   └── skills/
│       ├── skill-discovery/
│       ├── repo-skill-bootstrap/
│       ├── skill-maintenance/
│       └── shared-memory/
├── .github/
│   ├── ISSUE_TEMPLATE/agent-task.md
│   └── pull_request_template.md
├── docs/
│   └── agent-orchestrator.md
└── scripts/
    └── agents/
        ├── create-worktree.sh
        └── agent-memory
```

The installer is intentionally non-destructive: existing managed files are kept rather than overwritten.

## Four knowledge/capability layers

### `skill-discovery`

Find maintained external specialist skills for the **active task**, not merely the whole tech stack.

Examples of useful categories:

- UI/UX and design systems
- accessibility
- security review
- migrations
- testing
- framework-specific workflows

It must verify provenance/compatibility before recommending installation and must not install third-party code without approval.

### `repo-skill-bootstrap`

Discover project-specific knowledge that generic skills cannot know:

- service boundaries
- event-delivery guarantees
- auth invariants
- persistence ownership
- deployment conventions
- project-specific workflow constraints

### `skill-maintenance`

After major PRs, decide whether durable repository knowledge changed and whether an existing version-controlled skill should be updated.

### `shared-memory`

Use TencentDB Agent Memory selectively for historical context such as:

- prior architecture decisions
- important failure/root-cause patterns
- task outcomes
- extracted skills
- Wiki / CodeGraph knowledge

Memory is advisory. Current Git/GitHub evidence wins when they conflict.

## Safe memory CLI

When TencentDB Agent Memory is running:

```bash
agent-memory status
agent-memory search "reset token replay"
agent-memory remember "PR #214 made reset tokens single-use after successful consumption"
agent-memory skills "release verification"
```

The CLI uses Tencent's HTTP APIs and never opens the backing SQLite/Mongo database directly.

It prefixes search/write content with the current Git repository identity to reduce cross-project noise. This is a retrieval namespace, not an ACL/security boundary; use Tencent Memory Hub Teams/Users/Agents when stronger isolation is required.

## Skill discovery workflow

For a specialist task:

```text
Use skill-discovery to inspect this project's stack and the current task.
Recommend only external skills that materially improve execution.
Do not install anything yet.
For each recommendation show source, compatibility, install scope, context cost,
and supply-chain/security notes.
```

Then discover repository-specific knowledge separately:

```text
Use repo-skill-bootstrap to analyze this repository.
Do not create skills yet.
Return a proposed skill inventory with name, trigger, repository evidence,
invariants, and why it belongs in a skill instead of AGENTS.md.
Do not propose generic technology skills.
```

## Daily engineering flow

1. ChatGPT Web receives the goal.
2. Retrieve a few relevant shared memories only if history matters.
3. Inspect current GitHub/repository evidence.
4. Use `skill-discovery` when specialist external expertise helps.
5. Compress the result into a GitHub Issue task packet.
6. Create isolated worktrees for independent agents.
7. Codex / Antigravity implement.
8. GitHub Actions verifies deterministic checks.
9. ChatGPT reviews the actual diff and CI evidence.
10. Record only durable lessons; promote stable repeated workflows into version-controlled skills.

## Worktree helper

```bash
./scripts/agents/create-worktree.sh codex 142
./scripts/agents/create-worktree.sh antigravity 143
```

## Executor prompt

```text
Implement GitHub issue #142.

Read AGENTS.md and activate applicable repository skills.
Use Ponytail full when available.
Search shared memory only if historical context can materially help.
Treat the issue acceptance criteria as the contract.
Inspect analogous implementations before writing code.
Run the specified verification.
Review the final diff before completion.
```

## One-time external setup notes

### Ponytail

The harness uses the upstream host-specific installers when detected. Codex users should review/trust Ponytail's lifecycle hooks once via `/hooks` after installation.

### codex-chatgpt-web

This is an unofficial project that automates ChatGPT Web. The harness only downloads/runs its upstream installer after your explicit confirmation. Full Harness still requires an embedded-browser login and a ChatGPT Developer Mode connector setup. Review the upstream security model and applicable OpenAI/workspace policies before enabling it.

### TencentDB Agent Memory

The harness clones the official TencentCloud repository and delegates first boot to Tencent's own Docker scripts. The default backing store is SQLite in a Docker volume. The first boot asks for an LLM endpoint used by memory/knowledge extraction.

The local defaults are:

```text
Memory Core   http://127.0.0.1:8420
Panel UI      http://127.0.0.1:8125
Knowledge     http://127.0.0.1:8424
Tencent Proxy http://127.0.0.1:8096  # not used as Codex provider in this harness architecture
```

## Development

Validate shell syntax and run the smoke tests:

```bash
./scripts/test-harness.sh
```
