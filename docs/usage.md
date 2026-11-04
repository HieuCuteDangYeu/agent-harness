# Usage

## Start with one session

Open Orca, select a repository/worktree, and start **any available**
agent CLI. Ask it to follow `AGENTS.md` and use current code/tests.

- Trivial/easy: work directly here with low reasoning and targeted checks.
- Moderate: normally work directly here with medium reasoning; delegate
  only for real specialist or independent work.
- Hard: plan with high reasoning, then delegate if ownership,
  specialization, or isolation materially helps.
- Critical/high-risk: strongest supported reasoning, stringent
  verification, and an independent reviewer when available.

One capable current agent is preferable to several redundant workers.

## Multi-agent execution

If delegation is justified, refresh Orca Usage and compare actual
active-account/model-group limits, strengths, model/effort support,
reset windows, and permissions. Do not invent API endpoints or assume
every account reports data. An agent with more free quota is a good
choice only when it is sufficiently capable for that task.

Load `agent-harness orca guide`, then use Orca's live `orchestration`
skill. Orca owns Runs, dependencies, worktrees, workers, messages,
retries, and PASS/BLOCK gates. Prefer a small graph:

```text
implementation -> verification -> independent review -> PASS/BLOCK
```

The parent and workers must not edit the same owned task concurrently.
Review the final diff before shipping. Never claim unrun checks passed.

## Optional advisory selector

Prepare your own agent profiles and **recent**, manually checked Orca
Usage snapshot as described in [routing](routing.md). Then run:

```bash
agent-harness route --difficulty hard --domain backend \
  --config ~/.config/agent-harness/agents.json \
  --usage ~/.config/agent-harness/usage.json
```

It returns `stay_local`, `delegate`, or `manual_review`; does not
launch anything. Python 3 is only required for this optional tool.

## Optional integrations

```bash
agent-harness ready . --with-ponytail
agent-harness ready . --with-agentmemory
agent-harness memory start
agent-harness memory status
```

Ponytail's bundled installer supports some agents, not every Orca CLI.
agentmemory setup wires a subset of agent CLIs automatically; for other
agents use their documented MCP integration if supported.

## Safety and setup checks

```bash
git status --short
agent-harness doctor .
agent-harness orca doctor
```

Before a worker uses worktree state, ensure it can see the relevant
committed edits. Do not silently stash, commit, or discard local changes.

By default work remains local. A push, PR, or merge requires explicit
authorization. For Orca-specific skills use the installed guide, not
older copied CLI syntax.

The old `chatgpt-web` subcommand is disabled. Use native Orca agents,
and use ChatGPT Work separately for eligible ChatGPT web/connected-app
tasks; it is not an Orca provider credential.
