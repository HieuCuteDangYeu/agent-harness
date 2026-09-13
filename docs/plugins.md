# Runtime plugins and extensions

In this repository, **plugin** means the coding-agent plugins/extensions that the harness installs into Codex, Gemini CLI, or Antigravity. It does **not** mean ChatGPT app connectors such as Drive/Figma/Neon.

The two runtime integrations that matter to normal harness usage are:

| Integration | Where it runs | What it adds |
|---|---|---|
| Ponytail | Codex plugin, Gemini extension, Antigravity plugin | YAGNI/minimal-change guidance and lifecycle hooks |
| agentmemory | Codex plugin + MCP/hooks; Gemini/Antigravity adapters | Shared local engineering memory with selective recall/save tools |

`Codex Web GPT` is separate: it is a launcher/model/tool bridge used when you want a ChatGPT Web model to act as the orchestrator.

## Ponytail

The bootstrap installs Ponytail into every supported coding host it detects.

Codex installation performed by the harness:

```bash
codex plugin marketplace add DietrichGebert/ponytail
codex plugin add ponytail@ponytail
```

Gemini CLI:

```bash
gemini extensions install https://github.com/DietrichGebert/ponytail
```

Antigravity:

```bash
agy plugin install https://github.com/DietrichGebert/ponytail
```

### How Ponytail applies to your tasks

You do **not** manually call Ponytail before every task.

After installation/trust, the host loads it when that coding agent starts:

```text
interactive Codex task
        ↓
Codex loads Ponytail
        ↓
agent follows repo instructions + Ponytail simplicity guidance
```

The same is true for headless executor processes started by the automatic dispatcher:

```text
agent-harness orchestrate
        ↓
   codex exec / gemini
        ↓
host plugin/extension configuration loads
        ↓
Ponytail applies inside that executor process
```

`AGENTS.md` already tells agents to follow Ponytail when it is available, so normal task prompts do not need to repeat `use Ponytail` every time.

Ponytail is guidance, not authority. It must never simplify away authentication, authorization, validation, transactions, idempotency, concurrency protection, data integrity, error handling, security, or accessibility requirements.

### One-time Ponytail step

For Codex, launch `codex`, open `/hooks`, review the Ponytail lifecycle hooks, trust only what you accept, then start a new thread/restart Codex.

For Gemini/Antigravity, restart the host after installing the extension/plugin so the active session reloads it.

## agentmemory

The harness also installs/wires agentmemory into detected coding hosts.

For Codex it attempts:

```bash
codex plugin marketplace add rohitg00/agentmemory
codex plugin add agentmemory@agentmemory
npx -y @agentmemory/agentmemory@latest connect codex --with-hooks
```

Gemini and Antigravity use the upstream adapters:

```bash
npx -y @agentmemory/agentmemory@latest connect gemini-cli
npx -y @agentmemory/agentmemory@latest connect antigravity
```

The local service is managed by the harness:

```bash
agent-harness memory start
agent-harness memory status
agent-harness memory logs
agent-harness memory viewer
```

### How agentmemory applies to your tasks

agentmemory is **available** to connected agents, but broad context injection is intentionally disabled.

Normal behavior is:

```text
agent receives task
      ↓
reads AGENTS.md + relevant skills
      ↓
asks memory only if prior project history can materially help
      ↓
memory_smart_search / memory_recall
      ↓
verifies recalled facts against current code/tests
```

After verified work, an agent may save a concise durable lesson with `memory_save` or `memory_lesson_save` when future work is likely to benefit.

Do not use memory as a transcript store. Do not save secrets. Current code/tests/task requirements always override remembered summaries.

### Automatic orchestration and memory

Each Codex/Gemini executor launched by `agent-harness orchestrate` is a fresh CLI process. Because agentmemory is configured at the host level, that process can access the same shared memory service when its adapter/MCP is loaded.

The orchestrator does not need to copy the full memory history into every task. It should either:

- let an executor recall history itself when the task warrants it, or
- include only a few confirmed historical facts in the task packet when they are essential to the assignment.

## What is not a plugin

These are related harness components but have different roles:

- `AGENTS.md` — always-on repository instructions
- `.agents/skills/*` — version-controlled skills/invariants loaded when relevant
- `skill-discovery` — finds external specialist Agent Skills; it is not Ponytail
- `repo-skill-bootstrap` — proposes repository-specific skills
- `skill-maintenance` — keeps repository skills accurate
- `Codex Web GPT` — optional ChatGPT Web model/tool bridge
- `agent-harness orchestrate` — deterministic task scheduler/dispatcher

Think of the layers like this:

```text
AGENTS.md + relevant skills
          │
          ▼
Codex / Gemini executor
  ├── Ponytail       → implementation discipline
  └── agentmemory    → selective shared history
          │
          ▼
repository changes + verification
```

## Normal usage checklist

Once setup is complete, you normally only need:

```bash
agent-harness memory start
agent-harness chatgpt-web open   # only if using a ChatGPT Web orchestrator
codex
```

Then ask for the task normally. Ponytail and agentmemory are supporting runtime integrations; they should not turn every prompt into setup instructions.

If a plugin appears missing, rerun the normal bootstrap instead of manually maintaining separate install steps:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HieuCuteDangYeu/agent-harness/main/bootstrap.sh)
```
