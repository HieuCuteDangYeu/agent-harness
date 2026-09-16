#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
SECOND_LOG="$(mktemp)"
MOCK_LOG="$(mktemp)"
MIGRATION_LOG="$(mktemp)"
CUSTOM_LOG="$(mktemp)"
SNAPSHOT_LOG="$(mktemp)"
trap 'rm -rf "$TMP" "$SECOND_LOG" "$MOCK_LOG" "$MIGRATION_LOG" "$CUSTOM_LOG" "$SNAPSHOT_LOG"' EXIT

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

# Every untouched managed Markdown contract from v0.8.0 must migrate together.
# Full history is available in CI specifically so this fixture is the real old template set,
# not a hand-maintained copy that could drift away from what users actually installed.
LEGACY_MANAGED_COMMIT="fefb3bd9a52efcae3094019e28f7880cddc924a9"
MIGRATION_REPO="$TMP/migration-repo"
mkdir -p "$MIGRATION_REPO"
git -C "$MIGRATION_REPO" init -q
while IFS= read -r rel; do
  mkdir -p "$(dirname "$MIGRATION_REPO/$rel")"
  git -C "$ROOT" show "$LEGACY_MANAGED_COMMIT:templates/$rel" > "$MIGRATION_REPO/$rel"
done <<'MANAGED'
AGENTS.md
.agents/skills/repository-orchestrator/SKILL.md
.agents/skills/repo-skill-bootstrap/SKILL.md
.agents/skills/skill-discovery/SKILL.md
.agents/skills/skill-maintenance/SKILL.md
.agents/skills/shared-memory/SKILL.md
MANAGED

"$ROOT/bin/agent-harness" init "$MIGRATION_REPO" >"$MIGRATION_LOG"
while IFS= read -r rel; do
  cmp -s "$ROOT/templates/$rel" "$MIGRATION_REPO/$rel" || {
    echo "Managed template did not migrate: $rel" >&2
    cat "$MIGRATION_LOG" >&2
    exit 1
  }
done <<'MANAGED'
AGENTS.md
.agents/skills/repository-orchestrator/SKILL.md
.agents/skills/repo-skill-bootstrap/SKILL.md
.agents/skills/skill-discovery/SKILL.md
.agents/skills/skill-maintenance/SKILL.md
.agents/skills/shared-memory/SKILL.md
MANAGED
[[ "$(grep -c '^MIGRATE ' "$MIGRATION_LOG")" -ge 6 ]]

# A repository-owned edit at a managed path must survive future init/ready runs.
printf '\n# project-owned customization\n' >> "$MIGRATION_REPO/.agents/skills/skill-discovery/SKILL.md"
"$ROOT/bin/agent-harness" init "$MIGRATION_REPO" >"$CUSTOM_LOG"
grep -q '# project-owned customization' "$MIGRATION_REPO/.agents/skills/skill-discovery/SKILL.md"
grep -q 'skill-discovery/SKILL.md (modified/project-owned)' "$CUSTOM_LOG"

# Future upgrades do not need another growing hard-coded hash list: bootstrap snapshots
# the previously installed templates and passes them to init before replacing untouched files.
SNAPSHOT_TEMPLATES="$TMP/previous-templates"
SNAPSHOT_REPO="$TMP/snapshot-repo"
mkdir -p "$SNAPSHOT_TEMPLATES" "$SNAPSHOT_REPO"
git -C "$SNAPSHOT_REPO" init -q
printf '%s\n' 'future generated AGENTS contract' > "$SNAPSHOT_TEMPLATES/AGENTS.md"
printf '%s\n' 'future generated AGENTS contract' > "$SNAPSHOT_REPO/AGENTS.md"
AGENT_HARNESS_PREVIOUS_TEMPLATES="$SNAPSHOT_TEMPLATES" \
  "$ROOT/bin/agent-harness" init "$SNAPSHOT_REPO" >"$SNAPSHOT_LOG"
cmp -s "$ROOT/templates/AGENTS.md" "$SNAPSHOT_REPO/AGENTS.md"
grep -q '^MIGRATE .*AGENTS.md (untouched managed template)$' "$SNAPSHOT_LOG"

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

# Bootstrap snapshots the previous harness templates; init owns migration for all managed Markdown.
grep -q 'exec %q' "$ROOT/bootstrap.sh"
! grep -q 'scripts/orchestrate.mjs' "$ROOT/bootstrap.sh"
grep -q 'PREVIOUS_TEMPLATES=' "$ROOT/bootstrap.sh"
grep -q 'AGENT_HARNESS_PREVIOUS_TEMPLATES' "$ROOT/bootstrap.sh"
! grep -q 'OLD_AGENTS_BLOBS' "$ROOT/bootstrap.sh"
! grep -q 'OLD_ORCHESTRATOR_SKILL_BLOBS' "$ROOT/bootstrap.sh"
grep -q 'managed-template-hashes.tsv' "$ROOT/bin/agent-harness"
grep -q 'e96c62854ae40e3b4eb98a6386288d77e8fe07bd' "$ROOT/templates/managed-template-hashes.tsv"
grep -q '59c0a974014ce438038431e5e47feb1b2713e523' "$ROOT/templates/managed-template-hashes.tsv"
grep -q '45056413d833eb98b50738aad866e11f5e5a6ee3' "$ROOT/templates/managed-template-hashes.tsv"
grep -q '3750545ed76766c5ed5c80975c6ce77a24b633b8' "$ROOT/templates/managed-template-hashes.tsv"
grep -q 'ad817335a368c8ea4e49eafa33680e1d2bbf6204' "$ROOT/templates/managed-template-hashes.tsv"

# Persistent memory stays outside the repository.
grep -q 'export AGENTMEMORY_DATA_DIR="$DATA_ROOT"' "$ROOT/scripts/setup/agentmemory-service.sh"
grep -q 'export AGENTMEMORY_DATA_DIR="$DATA_ROOT"' "$ROOT/scripts/setup/install-agentmemory.sh"
DATA_DIR_OUTPUT="$(HOME="$TMP/home" XDG_DATA_HOME="$TMP/xdg-data" "$ROOT/bin/agent-harness" memory data-dir)"
test "$DATA_DIR_OUTPUT" = "$TMP/xdg-data/agentmemory"
test ! -e "$REPO/data"

echo "Harness smoke test passed."
