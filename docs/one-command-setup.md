# One-command setup

After installing `agent-harness` globally, run this inside any Git repository:

```bash
agent-harness ready .
```

The command performs all machine/project-side setup that can be safely automated.

## What it does

1. Installs the generic project harness without overwriting existing project files.
2. Adds:
   - `AGENTS.md`
   - `skill-discovery`
   - `repo-skill-bootstrap`
   - `skill-maintenance`
   - `shared-memory`
   - GitHub task/PR templates
   - worktree helper
   - project-local `agent-memory` helper
3. Installs a global `agent-memory` symlink under `~/.local/bin`.
4. Detects Codex, Antigravity/Gemini, Docker, Git, and curl.
5. Optionally installs Ponytail for detected agent hosts.
6. Optionally downloads/runs the upstream `codex-chatgpt-web` launcher installer.
7. Optionally clones and provisions TencentDB Agent Memory using its upstream Docker deployment.
8. Runs `agent-harness doctor` and prints remaining one-time manual actions.

## Why some steps stay manual

Two actions involve account/credential boundaries and should not be silently automated:

### ChatGPT Web login / Full Harness connector

`codex-chatgpt-web` requires you to sign in inside its embedded browser and configure the ChatGPT Developer Mode connector. The harness installs/prepares the launcher but does not manipulate your account or browser session for you.

### Tencent Memory first-boot LLM credentials

TencentDB Agent Memory uses an LLM for memory extraction/knowledge processing. Its official `start-all.sh` interactively asks for the Memory LLM and proxy upstream settings and tests connectivity before launching containers. The harness delegates this first boot to the upstream script rather than handling your API key itself.

## Non-interactive/CI use

Install only the project-side harness:

```bash
agent-harness ready . --core-only --non-interactive
```

Or selectively skip add-ons:

```bash
agent-harness ready . --skip-memory
agent-harness ready . --skip-chatgpt-web
agent-harness ready . --skip-ponytail
```

## After setup

Check memory:

```bash
agent-memory status
agent-memory search "why did we choose the outbox pattern"
```

For a task, the intended orchestration order is:

```text
shared-memory (only if useful)
        ↓
current repo inspection
        ↓
skill-discovery (only if specialist expertise helps)
        ↓
GitHub compact task packet
        ↓
Codex / Antigravity implementation
        ↓
CI
        ↓
ChatGPT review
        ↓
record durable memory / update skills if warranted
```
