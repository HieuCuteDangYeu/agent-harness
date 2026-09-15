#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
SECOND_LOG="$(mktemp)"
MOCK_LOG="$(mktemp)"
trap 'rm -rf "$TMP" "$SECOND_LOG" "$MOCK_LOG"' EXIT

REPO="$TMP/repo"
MOCK_BIN="$TMP/bin"
mkdir -p "$REPO" "$MOCK_BIN"
git -C "$REPO" init -q

"$ROOT/bin/agent-harness" init "$REPO"
"$ROOT/bin/agent-harness" doctor "$REPO" || true

"$ROOT/bin/agent-harness" init "$REPO" >"$SECOND_LOG"
if grep -q '^CREATE' "$SECOND_LOG"; then
  echo "Second init unexpectedly created managed files" >&2
  cat "$SECOND_LOG" >&2
  exit 1
fi

test -f "$REPO/AGENTS.md"
test -f "$REPO/.agents/skills/repository-orchestrator/SKILL.md"
test -f "$REPO/.agents/skills/repo-skill-bootstrap/SKILL.md"
test -f "$REPO/.agents/skills/skill-discovery/SKILL.md"
test -f "$REPO/.agents/skills/skill-maintenance/SKILL.md"
test -f "$REPO/.agents/skills/shared-memory/SKILL.md"

grep -q "Orca's live" "$REPO/AGENTS.md"
grep -q 'repository-policy wrapper for Orca' "$REPO/.agents/skills/repository-orchestrator/SKILL.md"
grep -q 'agent-harness orca guide' "$REPO/.agents/skills/repository-orchestrator/SKILL.md"
grep -q 'dirty' "$REPO/.agents/skills/repository-orchestrator/SKILL.md"
grep -q 'agentmemory' "$REPO/.agents/skills/shared-memory/SKILL.md"

test ! -e "$REPO/docs/agent-orchestrator.md"
test ! -e "$REPO/scripts/agents/create-worktree.sh"
test ! -e "$ROOT/templates/scripts/agents/create-worktree.sh"
test ! -e "$REPO/.github/ISSUE_TEMPLATE/agent-task.md"
test ! -e "$REPO/.github/pull_request_template.md"

# Orca is now the only task-level orchestration runtime shipped by the harness.
test ! -e "$ROOT/scripts/orchestrate.mjs"
test ! -e "$ROOT/scripts/orchestrator/core.mjs"
test ! -e "$ROOT/scripts/orchestrator/session.mjs"
test ! -e "$ROOT/scripts/orchestrator/agy-client.mjs"
test ! -e "$ROOT/scripts/agy-runner.mjs"
test ! -e "$ROOT/scripts/setup/agy-runner-service.sh"
test ! -e "$ROOT/scripts/test-orchestrator.sh"
test -f "$ROOT/scripts/setup/orca-control.sh"

# Old generated worktree helper is removed, but project-owned replacements survive.
mkdir -p "$REPO/scripts/agents"
printf '%s\n' 'project-owned helper' > "$REPO/scripts/agents/create-worktree.sh"
"$ROOT/bin/agent-harness" init "$REPO" >/dev/null
grep -q 'project-owned helper' "$REPO/scripts/agents/create-worktree.sh"
rm -rf "$REPO/scripts"

# Legacy generated memory/orchestrator files are still migrated safely.
printf '%s\n' 'check shared memory when `agent-memory` is available' > "$REPO/AGENTS.md"
printf '%s\n' 'legacy TencentDB Agent Memory skill' > "$REPO/.agents/skills/shared-memory/SKILL.md"
mkdir -p "$REPO/docs" "$REPO/scripts/agents"
printf '%s\n' 'legacy TencentDB Agent Memory orchestrator' > "$REPO/docs/agent-orchestrator.md"
printf '%s\n' '# TencentDB Agent Memory legacy helper' > "$REPO/scripts/agents/agent-memory"
"$ROOT/bin/agent-harness" init "$REPO" >/dev/null
grep -q "Orca's live" "$REPO/AGENTS.md"
! grep -q 'TencentDB Agent Memory' "$REPO/.agents/skills/shared-memory/SKILL.md"
test ! -e "$REPO/docs/agent-orchestrator.md"
test ! -e "$REPO/scripts/agents/agent-memory"

AGENT_HARNESS_NONINTERACTIVE=1 "$ROOT/bin/agent-harness" ready "$REPO" --core-only --non-interactive >/dev/null
"$ROOT/bin/agent-harness" --help >/dev/null
"$ROOT/bin/agent-harness" chatgpt-web --help >/dev/null
"$ROOT/bin/agent-harness" memory --help >/dev/null
"$ROOT/bin/agent-memory" --help >/dev/null

test "$("$ROOT/bin/agent-harness" version)" = "$(cat "$ROOT/VERSION")"

# Mock Orca proves CLI resolution, skill setup, live-guide loading, runtime checks, and Linux-neutral wrapper behavior.
cat > "$MOCK_BIN/orca" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_ORCA_LOG:?}"
case "${1:-}" in
  status) printf '%s\n' '{"ok":true}' ;;
  open) printf '%s\n' '{"ok":true,"opened":true}' ;;
  skills)
    case "${2:-}" in
      get) printf '%s\n' '# Orca live orchestration guide' ;;
      install|update) exit 0 ;;
      *) exit 2 ;;
    esac
    ;;
  *) exit 2 ;;
esac
MOCK
chmod +x "$MOCK_BIN/orca"

ORCA_ENV=(PATH="$MOCK_BIN:$PATH" ORCA_CLI_COMMAND=orca MOCK_ORCA_LOG="$MOCK_LOG")
env "${ORCA_ENV[@]}" "$ROOT/bin/agent-harness" orca doctor >/dev/null
env "${ORCA_ENV[@]}" "$ROOT/bin/agent-harness" orca setup >/dev/null
env "${ORCA_ENV[@]}" "$ROOT/bin/agent-harness" orca guide | grep -q 'Orca live orchestration guide'
grep -q '^skills install --skill orca-cli --skill orchestration$' "$MOCK_LOG"

# Legacy direct orchestration commands now fail with migration guidance.
if "$ROOT/bin/agent-harness" orchestrate status >/dev/null 2>&1; then
  echo "legacy orchestrate command must not execute" >&2
  exit 1
fi
if "$ROOT/bin/agent-harness" agy status >/dev/null 2>&1; then
  echo "legacy agy host-runner command must not execute" >&2
  exit 1
fi

# Bootstrap keeps the wrapper simple and migrates untouched v0.7.x generated contracts.
grep -q 'exec %q' "$ROOT/bootstrap.sh"
! grep -q 'scripts/orchestrate.mjs' "$ROOT/bootstrap.sh"
grep -q '1870515c2e33d59cfd94c4bc60d75de3f40d1265' "$ROOT/bootstrap.sh"
grep -q '4fb4b2205e608965d62a09551b8310249ca55e49' "$ROOT/bootstrap.sh"
grep -q 'Orca-backed orchestration policy' "$ROOT/bootstrap.sh"

# Persistent memory stays outside the repository.
grep -q 'export AGENTMEMORY_DATA_DIR="$DATA_ROOT"' "$ROOT/scripts/setup/agentmemory-service.sh"
grep -q 'export AGENTMEMORY_DATA_DIR="$DATA_ROOT"' "$ROOT/scripts/setup/install-agentmemory.sh"
DATA_DIR_OUTPUT="$(HOME="$TMP/home" XDG_DATA_HOME="$TMP/xdg-data" "$ROOT/bin/agent-harness" memory data-dir)"
test "$DATA_DIR_OUTPUT" = "$TMP/xdg-data/agentmemory"
test ! -e "$REPO/data"

echo "Harness smoke test passed."
