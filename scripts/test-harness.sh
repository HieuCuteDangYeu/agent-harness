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

test -f "$TMP/AGENTS.md"
test -f "$TMP/.agents/skills/repository-orchestrator/SKILL.md"
test -f "$TMP/.agents/skills/repo-skill-bootstrap/SKILL.md"
test -f "$TMP/.agents/skills/skill-discovery/SKILL.md"
test -f "$TMP/.agents/skills/skill-maintenance/SKILL.md"
test -f "$TMP/.agents/skills/shared-memory/SKILL.md"

grep -q 'Codex native subagents' "$TMP/AGENTS.md"
grep -q 'host-side `agy` runner' "$TMP/AGENTS.md"
grep -q 'Never silently fall back between Codex and `agy`' "$TMP/AGENTS.md"
grep -q 'spawn_agent' "$TMP/.agents/skills/repository-orchestrator/SKILL.md"
grep -q 'agent-harness agy status' "$TMP/.agents/skills/repository-orchestrator/SKILL.md"
grep -q 'host-side runner' "$TMP/.agents/skills/repository-orchestrator/SKILL.md"
grep -q 'agentmemory' "$TMP/.agents/skills/shared-memory/SKILL.md"

test ! -e "$TMP/docs/agent-orchestrator.md"
test ! -e "$TMP/scripts/agents/create-worktree.sh"
test ! -e "$ROOT/templates/scripts/agents/create-worktree.sh"
test ! -e "$TMP/.github/ISSUE_TEMPLATE/agent-task.md"
test ! -e "$TMP/.github/pull_request_template.md"

# Codex execution belongs to native subagents; Antigravity execution belongs to the host runner.
grep -q "SUPPORTED_AGENTS = new Set(\['codex', 'agy'\])" "$ROOT/scripts/orchestrator/core.mjs"
! grep -q "runProcess('codex'" "$ROOT/scripts/orchestrator/core.mjs"
! grep -q 'CODEX_SQLITE_HOME' "$ROOT/scripts/orchestrator/core.mjs"
! grep -q -- '--ephemeral' "$ROOT/scripts/orchestrator/core.mjs"
! grep -q "spawn('agy'" "$ROOT/scripts/orchestrator/core.mjs"
grep -q "spawn('agy'" "$ROOT/scripts/agy-runner.mjs"
grep -q 'submitAgyJob' "$ROOT/scripts/orchestrator/core.mjs"
test -f "$ROOT/scripts/orchestrator/agy-client.mjs"
test -f "$ROOT/scripts/setup/agy-runner-service.sh"
test -f "$ROOT/scripts/agy-runner.mjs"
test -f "$ROOT/scripts/orchestrator/session.mjs"

# Old generated worktree helper is removed, but project-owned replacements survive.
mkdir -p "$TMP/scripts/agents"
printf '%s\n' 'project-owned helper' > "$TMP/scripts/agents/create-worktree.sh"
"$ROOT/bin/agent-harness" init "$TMP" >/dev/null
grep -q 'project-owned helper' "$TMP/scripts/agents/create-worktree.sh"
rm -rf "$TMP/scripts"

# Legacy generated memory/orchestrator files are still migrated safely.
printf '%s\n' 'check shared memory when `agent-memory` is available' > "$TMP/AGENTS.md"
printf '%s\n' 'legacy TencentDB Agent Memory skill' > "$TMP/.agents/skills/shared-memory/SKILL.md"
mkdir -p "$TMP/docs" "$TMP/scripts/agents"
printf '%s\n' 'legacy TencentDB Agent Memory orchestrator' > "$TMP/docs/agent-orchestrator.md"
printf '%s\n' '# TencentDB Agent Memory legacy helper' > "$TMP/scripts/agents/agent-memory"
"$ROOT/bin/agent-harness" init "$TMP" >/dev/null
grep -q 'Codex native subagents' "$TMP/AGENTS.md"
! grep -q 'TencentDB Agent Memory' "$TMP/.agents/skills/shared-memory/SKILL.md"
test ! -e "$TMP/docs/agent-orchestrator.md"
test ! -e "$TMP/scripts/agents/agent-memory"

AGENT_HARNESS_NONINTERACTIVE=1 "$ROOT/bin/agent-harness" ready "$TMP" --core-only --non-interactive >/dev/null
"$ROOT/bin/agent-harness" --help >/dev/null
"$ROOT/bin/agent-harness" chatgpt-web --help >/dev/null
"$ROOT/bin/agent-harness" memory --help >/dev/null
HOME="$TMP/home" XDG_STATE_HOME="$TMP/state-home" "$ROOT/bin/agent-harness" agy queue-dir >/dev/null
"$ROOT/bin/agent-memory" --help >/dev/null

test "$("$ROOT/bin/agent-harness" version)" = "$(cat "$ROOT/VERSION")"

# Bootstrap keeps the wrapper stable and migrates untouched generated contracts.
grep -q 'rm -f "$BIN_DIR/agent-harness"' "$ROOT/bootstrap.sh"
grep -q 'exec node %q' "$ROOT/bootstrap.sh"
grep -q '74a3955795a1bc303bd03bcb173b56f99718ce19' "$ROOT/bootstrap.sh"
grep -q '442d129575564554ed6a4f256cc31f114b35e7ae' "$ROOT/bootstrap.sh"
grep -q 'current host-runner runtime' "$ROOT/bootstrap.sh"

# Persistent memory must stay outside the repository.
grep -q 'export AGENTMEMORY_DATA_DIR="$DATA_ROOT"' "$ROOT/scripts/setup/agentmemory-service.sh"
grep -q 'export AGENTMEMORY_DATA_DIR="$DATA_ROOT"' "$ROOT/scripts/setup/install-agentmemory.sh"
DATA_DIR_OUTPUT="$(HOME="$TMP/home" XDG_DATA_HOME="$TMP/xdg-data" "$ROOT/bin/agent-harness" memory data-dir)"
test "$DATA_DIR_OUTPUT" = "$TMP/xdg-data/agentmemory"
test ! -e "$TMP/data"

echo "Harness smoke test passed."
