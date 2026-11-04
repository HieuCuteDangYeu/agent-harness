---
name: repository-orchestrator
description: Agent-neutral repository-policy wrapper for Orca; delegates execution to the live Orca orchestration skill.
---

# Repository Orchestrator Compatibility Shim

This is a **repository-policy wrapper for Orca**, not a second orchestrator.
The parent may be **any** Orca-supported agent. Do not default to Codex or
Antigravity solely because older harness versions used them.

## Start in the current session

Read the task, current code/tests, AGENTS.md, and relevant local state.
Classify complexity: trivial/easy -> execute here with low effort;
moderate -> usually execute here with medium effort; hard -> consider a
specialist or isolated Orca worker with high effort; critical/high-risk ->
strongest supported reasoning plus explicit independent verification.

Spawn a worker only if capability, parallel ownership, independent analysis,
or isolation materially improves the result. Never create sibling tasks
merely to use more agents. Parent and worker must not edit the same owned task
concurrently. For complex work, prefer the smallest graph:
implementation -> verification -> independent review -> PASS/BLOCK.

## Routing checklist

Before launching an external worker, identify available agents and their
actual supported models/efforts in Orca Settings -> Agents.

- Match capabilities to the job; do not assume one provider wins every domain.
- Choose a model/reasoning level appropriate to task difficulty, using options
  actually supported on this host.
- Refresh Orca Usage for each *active account/model-group pool*. Compare the
  tightest 5h/daily/weekly limit and reset time, not only headline percentages.
- Prefer stronger task fit first; use healthier quota headroom as an important
  tiebreaker. Treat 80%+ usage as a caution, preserve a reserve for critical work.
- Unknown/stale/unavailable quota is **unknown**, not free or unlimited.
  Do not fabricate CLI/API usage data or infer it from a failed request.
- Keep secrets, approval boundaries, and provider access policies intact.

For reproducible recommendations, `agent-harness route` accepts profiles
and a manually verified recent Orca Usage snapshot. It **does not** read
live quotas or start workers. The final launch belongs to Orca's skill.

## Orca control plane

Before mutating any Run, task, session, or gate, load **Orca's live**
version-matched guide with `agent-harness orca guide` or the installed
`orchestration` skill. Do not hard-code historical CLI flags.

Orca owns worktrees, supervised agent sessions, messages, recovery, model/
effort launch controls, dependencies, and PASS/BLOCK gates.

## Dirty checkout and verification

Inspect `git status --porcelain` for dirty state. Worktrees do not inherit uncommitted
changes from another checkout; do not silently stash, commit, or lose them.

Run relevant tests, then required wider checks. Record evidence, not worker
self-reports. Keep an independent reviewer when task risk justifies it.
Do not push, open remote PRs, or merge without explicit authorization.

## Never

- revive the custom `agent-harness orchestrate` DAG or `agy` host runner
- reinstall or require Codex Web GPT as a parent transport
- assume all Orca providers expose the same models, effort, or quota API
- run sibling workers on the same implementation without a real boundary
- bypass permission or quota limits to complete a task
