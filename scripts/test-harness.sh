#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
SECOND_LOG="$(mktemp)"
MIGRATION_LOG="$(mktemp)"
trap 'rm -rf "$TMP" "$SECOND_LOG" "$MIGRATION_LOG"' EXIT

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
test -f "$TMP/.agents/skills/shared-memory/SKILL.md"
grep -q 'agentmemory' "$TMP/.agents/skills/shared-memory/SKILL.md"
test ! -e "$TMP/scripts/agents/agent-memory"
test ! -e "$TMP/.agent-harness-version"
test "$("$ROOT/bin/agent-harness" version)" = "$(cat "$ROOT/VERSION")"

# v0.3.x migration: known Tencent/generated memory references are replaced/removed.
printf '%s\n' 'check shared memory when `agent-memory` is available' > "$TMP/AGENTS.md"
printf '%s\n' 'legacy TencentDB Agent Memory skill' > "$TMP/.agents/skills/shared-memory/SKILL.md"
printf '%s\n' 'legacy TencentDB Agent Memory orchestrator' > "$TMP/docs/agent-orchestrator.md"
printf '%s\n' '# TencentDB Agent Memory legacy helper' > "$TMP/scripts/agents/agent-memory"
"$ROOT/bin/agent-harness" init "$TMP" >"$MIGRATION_LOG"
grep -q '^MIGRATE ' "$MIGRATION_LOG"
grep -q '^REMOVE  ' "$MIGRATION_LOG"
grep -q 'agentmemory' "$TMP/AGENTS.md"
! grep -q 'TencentDB Agent Memory' "$TMP/.agents/skills/shared-memory/SKILL.md"
! grep -q 'TencentDB Agent Memory' "$TMP/docs/agent-orchestrator.md"
test ! -e "$TMP/scripts/agents/agent-memory"

AGENT_HARNESS_NONINTERACTIVE=1 \
  "$ROOT/bin/agent-harness" ready "$TMP" --core-only --non-interactive >/dev/null

"$ROOT/bin/agent-harness" --help >/dev/null
"$ROOT/bin/agent-harness" chatgpt-web --help >/dev/null
"$ROOT/bin/agent-harness" memory --help >/dev/null
"$ROOT/bin/agent-memory" --help >/dev/null

# Setup must delegate long-running agentmemory to the detached lifecycle helper.
grep -q 'SERVICE_SCRIPT=.*agentmemory-service.sh' "$ROOT/scripts/setup/install-agentmemory.sh"
grep -q 'bash "$SERVICE_SCRIPT" start' "$ROOT/scripts/setup/install-agentmemory.sh"
grep -q 'nohup env CI=1 npx -y "$PACKAGE"' "$ROOT/scripts/setup/agentmemory-service.sh"
if grep -Eq '^[[:space:]]*CI=1 npx -y "\$PACKAGE"[[:space:]]*$' "$ROOT/scripts/setup/install-agentmemory.sh"; then
  echo "install-agentmemory.sh must not run the long-lived worker in foreground" >&2
  exit 1
fi

echo "Harness smoke test passed."
