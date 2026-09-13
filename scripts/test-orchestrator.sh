#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO="$TMP/repo"
MOCK_BIN="$TMP/bin"
mkdir -p "$REPO" "$MOCK_BIN"

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
while (($#)); do
  if [[ "$1" == "--output-last-message" ]]; then
    result="$2"
    shift 2
  else
    shift
  fi
done
cat >/dev/null || true
if [[ "${AGENT_HARNESS_TASK_ID:-}" == "review" ]]; then
  printf 'Review complete.\nVERDICT: PASS\n' > "$result"
else
  printf '%s\n' "$AGENT_HARNESS_TASK_ID" > "codex-$AGENT_HARNESS_TASK_ID.txt"
  printf 'done\n' > "$result"
fi
MOCK
chmod +x "$MOCK_BIN/codex"

cat > "$MOCK_BIN/gemini" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$AGENT_HARNESS_TASK_ID" > "gemini-$AGENT_HARNESS_TASK_ID.txt"
printf 'done\n'
MOCK
chmod +x "$MOCK_BIN/gemini"

cat > "$REPO/plan.json" <<'JSON'
{
  "version": 1,
  "name": "smoke",
  "goal": "prove dependency scheduling and integration",
  "base": "HEAD",
  "maxParallel": 2,
  "tasks": [
    {"id":"a","agent":"codex","prompt":"make a","verify":["test -f codex-a.txt"]},
    {"id":"b","agent":"gemini","prompt":"make b","verify":["test -f gemini-b.txt"]},
    {"id":"c","agent":"codex","prompt":"make c","dependsOn":["a","b"],"verify":["test -f codex-a.txt && test -f gemini-b.txt && test -f codex-c.txt"]}
  ],
  "review": {"agent":"codex"}
}
JSON

git -C "$REPO" add plan.json
git -C "$REPO" commit -qm plan

(
  cd "$REPO"
  PATH="$MOCK_BIN:$PATH" node "$ROOT/scripts/orchestrate.mjs" plan.json --dry-run >/dev/null
  PATH="$MOCK_BIN:$PATH" node "$ROOT/scripts/orchestrate.mjs" plan.json > "$TMP/output.log"
)

BRANCH="$(sed -n 's/^BRANCH  //p' "$TMP/output.log")"
STATE="$(sed -n 's/^STATE   //p' "$TMP/output.log")"
test -n "$BRANCH"
test -n "$STATE"

git -C "$REPO" show "$BRANCH:codex-a.txt" >/dev/null
git -C "$REPO" show "$BRANCH:gemini-b.txt" >/dev/null
git -C "$REPO" show "$BRANCH:codex-c.txt" >/dev/null

node - "$STATE/summary.json" <<'NODE'
const fs = require('fs');
const summary = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (summary.status !== 'success') process.exit(1);
if (summary.review?.verdict !== 'PASS') process.exit(1);
if (summary.tasks.some((task) => task.status !== 'success')) process.exit(1);
NODE

# Runtime state belongs under .git and must not pollute the working tree.
test -f "$STATE/summary.json"
test -z "$(git -C "$REPO" status --porcelain)"

echo "Orchestrator smoke test passed."
