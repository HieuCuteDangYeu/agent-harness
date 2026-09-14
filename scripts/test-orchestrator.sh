#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO="$TMP/repo"
MOCK_BIN="$TMP/bin"
STATE_DIR="$TMP/state"
mkdir -p "$REPO" "$MOCK_BIN" "$STATE_DIR"

git -C "$REPO" init -q
git -C "$REPO" config user.name test
git -C "$REPO" config user.email test@example.com
printf 'base\n' > "$REPO/base.txt"
git -C "$REPO" add .
git -C "$REPO" commit -qm base

cat > "$MOCK_BIN/agy" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${AGENT_HARNESS_TASK_ID:-}" == "review" ]]; then
  printf 'Review complete.\nVERDICT: PASS\n'
else
  printf '%s\n' "$AGENT_HARNESS_TASK_ID" > "task-$AGENT_HARNESS_TASK_ID.txt"
  printf 'done\n'
fi
MOCK
chmod +x "$MOCK_BIN/agy"

cat > "$REPO/plan.json" <<'JSON'
{
  "version": 1,
  "name": "native-smoke",
  "goal": "prove native Codex worktree handoff plus agy integration",
  "maxParallel": 2,
  "tasks": [
    {"id":"a","agent":"codex","prompt":"make a","verify":["test -f task-a.txt"]},
    {"id":"b","agent":"agy","prompt":"make b","dependsOn":["a"],"verify":["test -f task-a.txt && test -f task-b.txt"]}
  ],
  "review": {"agent":"codex","prompt":"review the integrated result"}
}
JSON

git -C "$REPO" add plan.json
git -C "$REPO" commit -qm plan
printf 'keep me dirty\n' > "$REPO/local-dirty.txt"

run_harness() {
  (
    cd "$REPO"
    PATH="$MOCK_BIN:$PATH" AGENT_HARNESS_STATE_DIR="$STATE_DIR" node "$ROOT/scripts/orchestrate.mjs" "$@"
  )
}

PREPARE_OUTPUT="$(run_harness prepare plan.json)"
RUN_ID="$(printf '%s\n' "$PREPARE_OUTPUT" | sed -n 's/^RUN     //p')"
test -n "$RUN_ID"
printf '%s\n' "$PREPARE_OUTPUT" | grep -q '^BASELINE caller-worktree '

READY_OUTPUT="$(run_harness ready "$RUN_ID")"
printf '%s\n' "$READY_OUTPUT" | grep -q '^READY   a agent=codex$'
! printf '%s\n' "$READY_OUTPUT" | grep -q '^READY   b '

TASK_OUTPUT="$(run_harness task "$RUN_ID" a)"
WORKTREE_A="$(printf '%s\n' "$TASK_OUTPUT" | sed -n 's/^WORKTREE //p')"
test -d "$WORKTREE_A"
printf '%s\n' "$TASK_OUTPUT" | grep -q '^PROMPT_BEGIN$'
printf '%s\n' "$TASK_OUTPUT" | grep -q 'Do not create or delegate to additional agents'
printf 'a\n' > "$WORKTREE_A/task-a.txt"
run_harness complete "$RUN_ID" a | grep -q '^DONE    a$'

READY_OUTPUT="$(run_harness ready "$RUN_ID")"
printf '%s\n' "$READY_OUTPUT" | grep -q '^READY   b agent=agy$'
run_harness agy "$RUN_ID" b | grep -q '^DONE    b$'

STATUS_OUTPUT="$(run_harness status "$RUN_ID")"
printf '%s\n' "$STATUS_OUTPUT" | grep -q '^STATUS  review_pending$'
printf '%s\n' "$STATUS_OUTPUT" | grep -q '^TASK    a success agent=codex'
printf '%s\n' "$STATUS_OUTPUT" | grep -q '^TASK    b success agent=agy'

REVIEW_OUTPUT="$(run_harness review-task "$RUN_ID")"
REVIEW_WORKTREE="$(printf '%s\n' "$REVIEW_OUTPUT" | sed -n 's/^WORKTREE //p')"
test -d "$REVIEW_WORKTREE"
printf '%s\n' "$REVIEW_OUTPUT" | grep -q '^REVIEW  agent=codex$'
run_harness review "$RUN_ID" PASS | grep -q '^REVIEW  success verdict=PASS$'

DELIVER_OUTPUT="$(run_harness deliver "$RUN_ID")"
printf '%s\n' "$DELIVER_OUTPUT" | grep -q '^STATUS  success$'
printf '%s\n' "$DELIVER_OUTPUT" | grep -q '^APPLIED yes$'

test -f "$REPO/task-a.txt"
test -f "$REPO/task-b.txt"
test -f "$REPO/local-dirty.txt"
grep -q 'keep me dirty' "$REPO/local-dirty.txt"
test ! -e "$REPO/.git/agent-harness"

FINAL_STATUS="$(run_harness status "$RUN_ID")"
printf '%s\n' "$FINAL_STATUS" | grep -q '^STATUS  success$'
printf '%s\n' "$FINAL_STATUS" | grep -q '^REVIEW  success agent=codex verdict=PASS$'

# Obsolete executors are rejected before any run is prepared.
cat > "$REPO/gemini-plan.json" <<'JSON'
{"version":1,"goal":"reject obsolete executor","tasks":[{"id":"x","agent":"gemini","prompt":"x"}]}
JSON
if run_harness prepare gemini-plan.json >/dev/null 2>&1; then
  echo "gemini must not be accepted as an executor" >&2
  exit 1
fi

# Codex is never launched as a nested CLI worker by the helper.
! grep -q "runProcess('codex'" "$ROOT/scripts/orchestrator/core.mjs"
! grep -q 'CODEX_SQLITE_HOME' "$ROOT/scripts/orchestrator/core.mjs"

echo "Orchestrator smoke test passed."
