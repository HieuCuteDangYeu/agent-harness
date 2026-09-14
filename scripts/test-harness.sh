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
grep -q 'Never launch a nested `codex exec` worker' "$TMP/AGENTS.md"
grep -q 'spawn_agent' "$TMP/.agents/skills/repository-orchestrator/SKILL.md"
grep -q 'agent-harness orchestrate prepare' "$TMP/.agents/skills/repository-orchestrator/SKILL.md"
grep -q 'agentmemory' "$TMP/.agents/skills/shared-memory/SKILL.md"

test ! -e "$TMP/docs/agent-orchestrator.md"
test ! -e "$TMP/scripts/agents/create-worktree.sh"
test ! -e "$ROOT/templates/scripts/agents/create-worktree.sh"
test ! -e "$TMP/.github/ISSUE_TEMPLATE/agent-task.md"
test ! -e "$TMP/.github/pull_request_template.md"

# The helper owns Git/worktree state; Codex execution belongs to native subagents.
grep -q "SUPPORTED_AGENTS = new Set(\['codex', 'agy'\])" "$ROOT/scripts/orchestrator/core.mjs"
! grep -q "runProcess('codex'" "$ROOT/scripts/orchestrator/core.mjs"
! grep -q 'CODEX_SQLITE_HOME' "$ROOT/scripts/orchestrator/core.mjs"
! grep -q -- '--ephemeral' "$ROOT/scripts/orchestrator/core.mjs"
test ! -e "$ROOT/scripts/orchestrator/executor.mjs"
test ! -e "$ROOT/scripts/orchestrator/run.mjs"
test ! -e "$ROOT/scripts/orchestrator/lifecycle.mjs"
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
"$ROOT/bin/agent-memory" --help >/dev/null

test "$("$ROOT/bin/agent-harness" version)" = "$(cat "$ROOT/VERSION")"

# Bootstrap keeps the wrapper stable and migrates untouched v0.6.x generated contracts.
grep -q 'rm -f "$BIN_DIR/agent-harness"' "$ROOT/bootstrap.sh"
grep -q 'exec node %q' "$ROOT/bootstrap.sh"
grep -q '690cc85979bf15c3aa99468a34f30618155b3fa8' "$ROOT/bootstrap.sh"
grep -q 'bdbd44332809943b596dad4a85a11b073bfc7fa1' "$ROOT/bootstrap.sh"
grep -q 'current native-subagent runtime' "$ROOT/bootstrap.sh"

# Persistent memory must stay outside the repository.
grep -q 'export AGENTMEMORY_DATA_DIR="$DATA_ROOT"' "$ROOT/scripts/setup/agentmemory-service.sh"
grep -q 'export AGENTMEMORY_DATA_DIR="$DATA_ROOT"' "$ROOT/scripts/setup/install-agentmemory.sh"
DATA_DIR_OUTPUT="$(HOME="$TMP/home" XDG_DATA_HOME="$TMP/xdg-data" "$ROOT/bin/agent-harness" memory data-dir)"
test "$DATA_DIR_OUTPUT" = "$TMP/xdg-data/agentmemory"
test ! -e "$TMP/data"

echo "Harness smoke test passed."
