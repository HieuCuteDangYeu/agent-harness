# Architecture

`agent-harness` is a **workflow/policy and integration layer around Orca**, not a second orchestration runtime.

The preferred human experience is the Orca desktop GUI. The preferred agent execution surface is Orca's official Agent Skills and live version-matched guides.

```text
You in Orca GUI
      ↓
parent Codex / ChatGPT Web session
      ↓
AGENTS.md workflow policy
      ↓
Orca official orchestration skill
      ↓
Orca Run + worktrees + worker sessions
 ├─ Codex
 ├─ Antigravity (`agy`)
 └─ other Orca-supported agents only when useful
      ↓
verification + independent review
      ↓
PASS / BLOCK decision gate
      ↓
review integrated diff in Orca GUI
      ↓
ship only when explicitly authorized
```

## Four layers

### 1. Human control plane: Orca GUI

The Orca desktop app is the source of truth for the human workflow:

- repositories and projects
- worktrees/workspaces
- agent tabs and multiple sessions
- Run/task visibility
- model/effort selection where exposed
- agent activity/status
- browser/design/device surfaces
- diff review and annotations
- commit/push/PR controls
- skill visibility and updates

The user should not need to reproduce normal GUI actions through `agent-harness` commands.

### 2. Agent execution plane: Orca Skills

Agents use Orca's maintained skills and live guides for capability-specific operations.

The important generic skills include:

- `orca-cli`
- `orchestration`
- `computer-use`
- `orca-emulator-android` when Android device/emulator work is needed

Before mutating orchestration state, the parent must load Orca's live, version-matched orchestration guide rather than relying on stale command syntax copied into the repository.

Orca therefore owns:

- Run/task graph state
- worktree creation/lifecycle
- worker sessions and status
- Codex / Antigravity launches
- worker messages and recovery
- model/reasoning-effort options
- decision gates
- review/diff surfaces

### 3. Repository policy plane: AGENTS.md + project-specific skills

`AGENTS.md` contains the workflow rules that Orca does not know automatically, such as:

- source-of-truth priority
- when to orchestrate versus stay single-agent
- worker preference
- verification/review requirements
- dirty-working-tree behavior
- memory policy
- YAGNI/minimal-change expectations
- remote push/PR/merge safety

Repository-local `.agents/skills/` should be used only for durable, non-obvious project-specific invariants or procedures.

Examples:

- authentication/authorization invariants unique to the repository
- event/outbox/idempotency guarantees
- service ownership boundaries
- persistence conventions
- media-processing workflows
- release/deployment procedures specific to the project

Generic orchestration, generic skill discovery, generic framework knowledge, and generic memory instructions should not become a second capability layer when Orca or an installed maintained skill already provides them.

The generic harness skills that remain are compatibility/policy shims for existing bootstrapped repositories; they should delegate to Orca rather than duplicate Orca's implementation.

### 4. Integration plane: agent-harness helpers

The harness installs or controls optional integrations that are outside Orca's core responsibility:

- Ponytail
- agentmemory
- Codex Web GPT
- Orca CLI/skill setup helpers
- generated `AGENTS.md`

This layer should stay thin.

## Why Orca owns orchestration

Orca already provides worktree-native isolation, multiple live agent sessions, Runs/tasks, worker supervision, messages, model/effort controls, status, diff review, and gates.

Maintaining another DAG/worktree/executor system underneath Orca would create competing sources of truth for ownership, retries, Git state, and worker lifecycle.

Therefore:

- no custom `agent-harness orchestrate` runtime
- no custom Antigravity host runner
- no sibling implementation workers outside an active Orca Run
- no parent implementation of a task currently owned by an Orca worker

## Parent session

The parent may be ordinary Codex or a ChatGPT Web model reached through Codex Web GPT.

```text
ChatGPT Web model (optional)
        ↓
Codex Web GPT bridge
        ↓
parent Codex session in Orca
        ↓
Orca orchestration
```

Codex Web GPT is never a repository worker. It is only transport for the parent model.

## Worker roles

**Codex** is the default implementation/debugging/repository-analysis/test worker.

**Antigravity** is useful for UI/device/visual work, emulator-oriented tasks, focused implementation, or independent review when it materially helps.

Other Orca-supported agents are allowed only when they provide a meaningful capability or independence boundary.

For substantial work, the default task graph is:

```text
implementation -> verification -> independent review -> PASS/BLOCK gate
```

Split further only for real ownership or dependency boundaries.

## Skill discovery

Use Orca's Skills UI, the agent's discovered skill picker, and Orca's built-in skill discovery / Find Skills surface when available before creating a local skill.

Prefer maintained external skills with inspectable provenance over copying generic knowledge into the repository.

A new local skill should be created only when the knowledge is:

- repository-specific
- stable across multiple future tasks
- non-obvious from nearby code
- important enough that violating it could cause correctness, security, or operational problems

## Dirty checkout boundary

Orca worktrees start from Git refs/commits. They do not automatically inherit uncommitted edits from another checkout.

Before a Run depends on local changes, inspect `git status`. If those edits matter, commit/snapshot them or continue from an Orca-managed branch/worktree that already contains them.

Agents must not silently stash, commit, or mutate the caller checkout merely to make it visible to a worker.

## Verification and review

A worker self-report is not verification evidence.

For substantial changes, keep verification and final review explicit. Run the narrowest meaningful checks first and block PASS when a required test/check fails.

The final reviewer should be independent from the implementation worker when practical.

## Shared memory

agentmemory is advisory historical context, not a source of truth.

```text
explicit task requirements
    > current repository code/tests
    > AGENTS.md + repository-specific skills
    > agentmemory
    > external/general research
```

Retrieve memory selectively and save only concise, verified lessons. Never store secrets, raw transcripts, or reproducible logs merely because they exist.

## Ponytail / simplicity

Follow minimal-change/YAGNI guidance, but never simplify away required:

- authentication
- authorization
- trust-boundary validation
- transactions
- concurrency protection
- idempotency guarantees
- data-integrity checks
- error handling
- security controls
- accessibility requirements

## Remote operations

Remote delivery remains user-controlled.

Do not push, create a remote PR, or merge unless explicitly requested. When shipping is authorized, prefer Orca's GUI review/commit/push/PR surfaces so the final integrated diff remains visible to the user.

## Codex Web GPT hook boundary

Codex Web GPT manages its own Codex `Interrupt` lifecycle hook and validates it against an integration journal. Other hook/trust operations may cause Codex to normalize `~/.codex/config.toml`.

If the bridge reports an inconsistent interrupt hook, verify the actual managed fragment and journal before changing anything. Do not delete unrelated Orca, Ponytail, or agentmemory hook state. Orca's Agent status hooks can be disabled temporarily from **Settings → Agents** while diagnosing conflicts.
