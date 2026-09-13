#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git -C "$TMP" init -q
"$ROOT/bin/agent-harness" init "$TMP"
"$ROOT/bin/agent-harness" doctor "$TMP"

"$ROOT/bin/agent-harness" init "$TMP" >/tmp/agent-harness-second-init.log
if grep -q '^CREATE' /tmp/agent-harness-second-init.log; then
  echo "Second init unexpectedly created managed files" >&2
  cat /tmp/agent-harness-second-init.log >&2
  exit 1
fi
rm -f /tmp/agent-harness-second-init.log

test -x "$TMP/scripts/agents/create-worktree.sh"
test "$(cat "$TMP/.agent-harness-version")" = "$(cat "$ROOT/VERSION")"

echo "Harness smoke test passed."
