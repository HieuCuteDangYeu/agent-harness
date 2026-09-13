#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
SECOND_LOG="$(mktemp)"
trap 'rm -rf "$TMP" "$SECOND_LOG"' EXIT

git -C "$TMP" init -q

"$ROOT/bin/agent-harness" init "$TMP"
"$ROOT/bin/agent-harness" doctor "$TMP" || true

"$ROOT/bin/agent-harness" init "$TMP" >"$SECOND_LOG"
if grep -q '^CREATE' "$SECOND_LOG"; then
  echo "Second init unexpectedly created managed files" >&2
  cat "$SECOND_LOG" >&2
  exit 1
fi

test -x "$TMP/scripts/agents/create-worktree.sh"
test -x "$TMP/scripts/agents/agent-memory"
test -f "$TMP/.agents/skills/shared-memory/SKILL.md"
test "$(cat "$TMP/.agent-harness-version")" = "$(cat "$ROOT/VERSION")"

AGENT_HARNESS_NONINTERACTIVE=1 \
  "$ROOT/bin/agent-harness" ready "$TMP" --core-only --non-interactive >/dev/null

"$ROOT/bin/agent-memory" --help >/dev/null

echo "Harness smoke test passed."
