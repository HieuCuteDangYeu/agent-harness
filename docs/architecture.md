# Architecture

The harness is a **policy layer**, not a replacement for Orca's own
orchestration, worktrees, or session management.

```text
User in Orca GUI
  -> any enabled parent agent CLI
  -> AGENTS.md: task triage
       easy / trivial -> work in current session
       moderate -> usually work in current session
       hard / critical -> consider delegation
  -> inspect agent capabilities + actual model/effort support
  -> inspect Orca Usage for active account and model-group headroom
  -> optional advisory "agent-harness route" (fresh manual snapshot)
  -> Orca live orchestration skill
  -> Orca Run: specialist implementation -> verification -> independent review
  -> PASS/BLOCK gate -> diff review -> authorized delivery
```

## Responsibilities

**Orca GUI and live skills:** repository and worktree state, running
agents (including custom CLIs), subscriptions/accounts, model/effort
launch controls, usage, Run/task lifecycle, messages, approvals, and
review gates. Always read `agent-harness orca guide` before mutating a Run;
Orca's CLI and UI capabilities may change.

**AGENTS.md + repository skills:** triage, evidence standards, provider
selection, quota caution, security, dirty-checkout handling, memory and
skill priorities. Parent agents need not be Codex. A local skill should
encode only stable and non-obvious project invariants.

**Optional advisory router:** `scripts/route_agent.py` reads
user-configured capability profiles and a fresh snapshot of Orca Usage.
It does not query or automate Orca, guess provider quotas, or create
worker sessions. It selects abstract supported effort and emits JSON
recommendations. See [routing](routing.md).

**Optional integrations:** Ponytail and local agentmemory. Their
agent-specific installers remain best-effort and opt-in, not hard
dependencies for using other agents.

## Trust and failure boundaries

Never let stale memory, a quota snapshot, or an agent's claimed skills
override current code/tests or user requirements. Usage can be unavailable
or account-specific; missing numbers do not mean unlimited capacity.
A worker must not silently bypass permission controls or send secrets
to another provider. Review independent output and actual verification
evidence for risky work.

Orca worktrees do not inherit dirty edits from another checkout.
Never silently stash, commit, or lose edits. Keep one owner per
implementation task and avoid creating a second orchestration DAG.

## Retired bridge

Codex Web GPT and its unofficial browser-based parent transport are no
longer configured or launched by the harness. Existing installed files
outside this repository are left untouched. ChatGPT Work is a separate
product surface and not an assumed Orca agent CLI.
