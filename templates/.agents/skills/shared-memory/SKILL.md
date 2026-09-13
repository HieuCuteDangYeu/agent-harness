---
name: shared-memory
description: Use the optional shared TencentDB Agent Memory sidecar to recover relevant prior engineering decisions, failures, outcomes, and extracted skills without flooding the prompt. Use for substantial tasks where historical project context may avoid repeated exploration, and after meaningful work when a concise durable lesson should be preserved.
---

# Shared Agent Memory

Use shared memory to avoid rediscovering history. Never treat it as the source of truth.

## Source-of-truth order

For current implementation facts, prefer:

1. current repository code and tests
2. current GitHub issue/PR requirements
3. version-controlled `AGENTS.md` and repository skills
4. authoritative project documentation
5. shared memory

If memory conflicts with the current repository, the repository wins.

## Read path

When a substantial task may depend on prior decisions or failures, and `agent-memory` is available:

```bash
agent-memory search "<concise task or decision query>"
```

Use only the few results relevant to the task. Do not dump the entire memory store into context.

For reusable extracted skills:

```bash
agent-memory skills "<capability or workflow>"
```

Validate any returned skill against current repository conventions before relying on it.

Skip memory retrieval for trivial edits where historical context is unlikely to change the answer.

## Write path

Record only durable engineering knowledge after it has been verified, for example:

- accepted architecture decisions
- non-obvious invariants
- root causes of important failures
- successful remediation patterns
- task outcomes that future agents are likely to need

Use:

```bash
agent-memory remember "<short durable engineering fact with useful context>"
```

Do not store:

- passwords, API keys, tokens, secrets, or private credentials
- raw logs that can be reproduced
- full chat transcripts merely because they exist
- temporary implementation details
- speculative conclusions

Memory writes should be concise and evidence-based. When useful, mention the GitHub issue, PR, or commit in the recorded text so future retrieval can verify the source.

## Project isolation

The harness prefixes memory content/searches with the repository identity derived from Git remote or the repository directory. This is a lightweight namespace, not a security boundary. Use Tencent Memory Hub Team/User/Agent ACLs when stronger isolation is required.

## ChatGPT Web bridge

With `codex-chatgpt-web` Full Harness, ChatGPT Web can ask the local Codex harness to run the safe `agent-memory` CLI through its turn-bound tool surface.

Do not expose raw SQLite/Mongo administration or arbitrary database credentials to the web model. Prefer the narrow CLI/API operations in this harness.
