# Adaptive agent routing

This harness keeps **Orca as the only multi-agent execution plane**. Routing
is a decision made by the *current* agent, not a new worker scheduler.

## Decision flow

1. Read current code, tests, risks, and task scope. Estimate needed
   reasoning: trivial/easy -> low; moderate -> medium; hard -> high;
   critical -> strongest supported effort.
2. Trivial/easy work stays in the current session. Moderate work normally
   stays local unless a specialist, independent verification, or worktree
   boundary produces real value.
3. For hard/critical work, discover candidate agents enabled in Orca.
   Select by demonstrable task capability and tool/environment access first.
4. Check Orca's **Usage** popover for the specific selected **account and
   model-group pool**. Refresh before dispatch. Compare the most constrained
   5h, daily, and weekly window, plus reset times. Do not compare percentages
   from unrelated plans as if they were interchangeable absolute tokens.
5. Prefer adequate expertise *and* healthy quota headroom. Treat usage
   >=80% as constrained, reserve margin for urgent work, and never
   mistake an unavailable number for 0% usage.
6. Use Orca's live `orchestration` skill for dispatch, verification,
   reviewer independence, and PASS/BLOCK. Never create a competing DAG.

For high-risk tasks, independent verification is required, regardless of
implementation size. A worker's self-report is not proof of passing tests.

## Why the optional router takes a snapshot

Orca documents a multi-provider Usage display and account/model-group
tracking. **No stable public, machine-readable API for exporting all live
provider quotas has been verified.** The helper therefore accepts
user-provided snapshots instead of scraping Orca internals, parsing login
files, guessing quota percentages, or claiming to use a nonexistent
`orca usage --json` command.

If a future Orca version exposes a documented quota API, it can become an
adapter that produces the same JSON schema. Until then, inspect the UI and
update the snapshot immediately before choosing a worker. A stale snapshot
causes the router to return `manual_review`, not a fabricated selection.

## Configure any agent

Copy (do not run directly against the example data):

```bash
mkdir -p ~/.config/agent-harness
cp routing/agents.example.json ~/.config/agent-harness/agents.json
cp routing/usage.example.json ~/.config/agent-harness/usage.json
```

Remove the `_example_only` markers only after replacing the sample data with
verified local profiles/usage; enable only agents that actually exist in Orca.
The router refuses the example markers as a safety measure.

Edit `agents.json` so **each enabled agent ID is an Orca-available CLI**,
with its own provider, `quota_key` (unique per account/model pool),
`strengths` per task domain rated 0–5 based on **your own evaluation**,
and supported abstract `efforts` (`low`, `medium`, `high`, `max`).
Optional `models` maps an effort to an actual model ID confirmed in Orca.
The included scores are **illustrative**, not model benchmarks.

Edit `usage.json` with values from Orca's Usage popover for that account
and model group, a current UTC `observed_at`, and the reported time
windows. Each pool has `status: "available"` with numeric
`used_percent` in each window, or `status: "unavailable"` without invented
values. If you include `resets_at`, keep it as a timezone-aware ISO-8601
timestamp. If the reset time has passed, refresh the snapshot instead
of assuming the usage returned to zero. Never put credentials in the files.

```bash
agent-harness route --difficulty easy --domain backend
agent-harness route --difficulty hard --domain backend,security \
  --config ~/.config/agent-harness/agents.json \
  --usage ~/.config/agent-harness/usage.json
agent-harness route --difficulty critical --domain security --risk high \
  --config ~/.config/agent-harness/agents.json \
  --usage ~/.config/agent-harness/usage.json
```

Output is JSON: `stay_local`, `delegate` with one candidate plus alternatives,
or `manual_review`. The helper recommends reasoning effort, never launches
agents. Exit code 3 means manual quota/capability review is needed.
Profiles are **advisory** and must be checked against the actual host:
a command listed in JSON does not mean the CLI exists or has permissions.
The current parent must respect Orca's GUI/session constraints.

## Scoring and safety

- For hard work, an agent must score at least 3/5 in every requested domain;
  for critical/high-risk work, 4/5. Missing skills fail closed.
- The chosen effort is the minimum supported level at least as strong as
  requested; if unavailable, it uses the strongest configured level without
  fabricating one. Model IDs remain null unless the profile supplies them.
- Every quota window must have valid fresh data. Headroom is the **minimum**
  remaining percentage across windows. Pools below the reserved margin are
  excluded.
- Remaining candidates are ranked by
  `20 * mean_skill + 0.35 * quota_headroom - near_limit_penalty`.
  Skill usually dominates; healthier quota can change close decisions.
  This is a transparent heuristic, **not** a calibrated model benchmark.
- The default reserve is 15%; the default freshness limit is 30 minutes.
  Use `--reserve-percent` or `--max-age-minutes` to adjust, carefully.
- If all pools are missing, blocked, stale, or insufficient, **do not**
  auto-dispatch. Review Orca Usage or continue within the current session
  when safe. Never bypass permission prompts or provider limits.

Examples of real-world variation: a UI/device worker needs host access to
ADB/browser; an independent security reviewer needs demonstrated security
ability; a low-capability but high-quota provider is not automatically the
best choice for a critical migration.

## ChatGPT Work vs Orca

ChatGPT Work can handle web, local, and connected-app tasks, depending on
the enabled product experience. It does **not** automatically become an
Orca terminal agent or a subscription API. The old Codex Web GPT browser
bridge has therefore been retired from this harness without touching
existing installations on the user's computer. Native Orca agent CLIs
remain the supported worker entry point.
