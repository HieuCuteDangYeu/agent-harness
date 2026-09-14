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

cat > "$MOCK_BIN/codex" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
result=""
seen_approval=0
while (($#)); do
  case "$1" in
    --approve-for-me)
      echo "obsolete --approve-for-me used" >&2
      exit 91
      ;;
    --ask-for-approval)
      [[ "${2:-}" == "never" ]]
      seen_approval=1
      shift 2
      ;;
    --output-last-message)
      result="$2"
      shift 2
      ;;
    *) shift ;;
  esac
done
[[ "$seen_approval" -eq 1 ]]
cat >/dev/null || true
if [[ "${AGENT_HARNESS_TASK_ID:-}" == "review" ]]; then
  printf 'Review complete.\nVERDICT: PASS\n' > "$result"
else
  printf '%s\n' "$AGENT_HARNESS_TASK_ID" > "task-$AGENT_HARNESS_TASK_ID.txt"
  printf 'done\n' > "$result"
fi
MOCK
chmod +x "$MOCK_BIN/codex"

# No gemini executable is installed in this test. The logical gemini role must
# transparently use Antigravity when agy is available.
cat > "$MOCK_BIN/agy" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$AGENT_HARNESS_TASK_ID" > "task-$AGENT_HARNESS_TASK_ID.txt"
printf 'done\n'
MOCK
chmod +x "$MOCK_BIN/agy"

cat > "$REPO/plan.json" <<'JSON'
{
  "version": 1,
  "name": "smoke",
  "goal": "prove dependency scheduling, executor fallback, and integration",
  "base": "HEAD",
  "maxParallel": 2,
  "tasks": [
    {"id":"a","agent":"codex","prompt":"make a","verify":["test -f task-a.txt"]},
    {"id":"b","agent":"gemini","prompt":"make b","verify":["test -f task-b.txt"]},
    {"id":"c","agent":"codex","prompt":"make c","dependsOn":["a","b"],"verify":["test -f task-a.txt && test -f task-b.txt && test -f task-c.txt"]}
  ],
  "review": {"agent":"codex"}
}
JSON

git -C "$REPO" add plan.json
git -C "$REPO" commit -qm plan

# Foreground execution remains available for manual/debug use.
(
  cd "$REPO"
  PATH="$MOCK_BIN:$PATH" node "$ROOT/scripts/orchestrate.mjs" plan.json --dry-run > "$TMP/dry.log"
  grep -q 'fallback=agy' "$TMP/dry.log"
  PATH="$MOCK_BIN:$PATH" node "$ROOT/scripts/orchestrate.mjs" plan.json > "$TMP/output.log"
)

BRANCH="$(sed -n 's/^BRANCH  //p' "$TMP/output.log")"
STATE="$(sed -n 's/^STATE   //p' "$TMP/output.log")"
test -n "$BRANCH"
test -n "$STATE"
git -C "$REPO" show "$BRANCH:task-a.txt" >/dev/null
git -C "$REPO" show "$BRANCH:task-b.txt" >/dev/null
git -C "$REPO" show "$BRANCH:task-c.txt" >/dev/null

node - "$STATE/summary.json" <<'NODE'
const fs = require('fs');
const summary = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (summary.status !== 'success') process.exit(1);
if (summary.review?.verdict !== 'PASS') process.exit(1);
if (summary.tasks.some((task) => task.status !== 'success')) process.exit(1);
NODE

# Foreground debug mode intentionally uses caller Git metadata. Remove that
# state so the detached-mode assertion below proves it does not recreate it.
rm -rf "$REPO/.git/agent-harness"

# Detached mode must accept an existing dirty caller worktree, snapshot it as
# the agent baseline, avoid caller .git writes, and apply only the verified
# result patch back to the caller worktree.
printf 'keep me dirty\n' > "$REPO/local-dirty.txt"
START_OUTPUT="$(
  cd "$REPO"
  PATH="$MOCK_BIN:$PATH" AGENT_HARNESS_STATE_DIR="$STATE_DIR" \
    node "$ROOT/scripts/orchestrate.mjs" start plan.json
)"
RUN_ID="$(printf '%s\n' "$START_OUTPUT" | sed -n 's/^RUN     //p')"
test -n "$RUN_ID"
printf '%s\n' "$START_OUTPUT" | grep -q '^STATUS  started$'
printf '%s\n' "$START_OUTPUT" | grep -q '^BASELINE caller-worktree '

STATUS_OUTPUT=""
for _ in $(seq 1 200); do
  STATUS_OUTPUT="$(
    cd "$REPO"
    PATH="$MOCK_BIN:$PATH" AGENT_HARNESS_STATE_DIR="$STATE_DIR" \
      node "$ROOT/scripts/orchestrate.mjs" status "$RUN_ID"
  )"
  if printf '%s\n' "$STATUS_OUTPUT" | grep -q '^STATUS  success$'; then
    break
  fi
  sleep 0.05
done
printf '%s\n' "$STATUS_OUTPUT" | grep -q '^STATUS  success$'
printf '%s\n' "$STATUS_OUTPUT" | grep -q '^APPLIED yes$'
printf '%s\n' "$STATUS_OUTPUT" | grep -q '^REVIEW  success verdict=PASS$'

DETACHED_STATE="$(printf '%s\n' "$STATUS_OUTPUT" | sed -n 's/^STATE   //p')"
test -f "$DETACHED_STATE/summary.json"
test -f "$DETACHED_STATE/orchestrator.log"
test -f "$DETACHED_STATE/result.patch"
(cd "$REPO" && AGENT_HARNESS_STATE_DIR="$STATE_DIR" node "$ROOT/scripts/orchestrate.mjs" logs "$RUN_ID" 40) | grep -q '^RESULT  success$'

test -f "$REPO/local-dirty.txt"
grep -q 'keep me dirty' "$REPO/local-dirty.txt"
test -f "$REPO/task-a.txt"
test -f "$REPO/task-b.txt"
test -f "$REPO/task-c.txt"
test ! -e "$REPO/.git/agent-harness"
case "$DETACHED_STATE" in
  "$REPO/.git"/*) echo "detached state must not live under caller .git" >&2; exit 1 ;;
esac

echo "Orchestrator smoke test passed."
