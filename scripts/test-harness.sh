#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/project"
mkdir -p "$REPO"
git -C "$REPO" init -q

assert_no_generic_skills() {
  local target="$1" skill
  for skill in repository-orchestrator repo-skill-bootstrap skill-discovery skill-maintenance shared-memory; do
    test ! -e "$target/.agents/skills/$skill/SKILL.md" || {
      echo "Redundant skill unexpectedly installed: $skill" >&2
      exit 1
    }
  done
}

# Fresh install has exactly one generated prompt. Subsequent init is idempotent.
"$ROOT/bin/agent-harness" init "$REPO" >/dev/null
"$ROOT/bin/agent-harness" doctor "$REPO" >/dev/null
cmp "$ROOT/templates/AGENTS.md" "$REPO/AGENTS.md"
cmp "$ROOT/templates/.agents/skills/project-learning/SKILL.md" "$REPO/.agents/skills/project-learning/SKILL.md"
grep -q '^name: project-learning' "$REPO/.agents/skills/project-learning/SKILL.md"
assert_no_generic_skills "$REPO"
"$ROOT/bin/agent-harness" init "$REPO" >"$TMP/second.log"
! grep -qE '^(CREATE|MIGRATE|REMOVE) ' "$TMP/second.log"

# Real legacy templates: migrate only known exact generated files.
LEGACY_MANAGED_COMMIT="fefb3bd9a52efcae3094019e28f7880cddc924a9"
LEGACY="$TMP/legacy"
mkdir -p "$LEGACY"
git -C "$LEGACY" init -q
while IFS= read -r rel; do
  mkdir -p "$(dirname "$LEGACY/$rel")"
  git -C "$ROOT" show "$LEGACY_MANAGED_COMMIT:templates/$rel" >"$LEGACY/$rel"
done <<'MANAGED'
AGENTS.md
.agents/skills/repository-orchestrator/SKILL.md
.agents/skills/repo-skill-bootstrap/SKILL.md
.agents/skills/skill-discovery/SKILL.md
.agents/skills/skill-maintenance/SKILL.md
.agents/skills/shared-memory/SKILL.md
MANAGED
"$ROOT/bin/agent-harness" init "$LEGACY" >"$TMP/migration.log"
cmp "$ROOT/templates/AGENTS.md" "$LEGACY/AGENTS.md"
cmp "$ROOT/templates/.agents/skills/project-learning/SKILL.md" "$LEGACY/.agents/skills/project-learning/SKILL.md"
assert_no_generic_skills "$LEGACY"
test "$(grep -c 'untouched obsolete harness shim' "$TMP/migration.log")" -eq 5

# Changed/user-owned instructions and skills are never overwritten or deleted.
CUSTOM="$TMP/custom"
cp -a "$LEGACY" "$CUSTOM"
mkdir -p "$CUSTOM/.agents/skills/skill-discovery"
printf '%s\n' 'project-specific instructions' >>"$CUSTOM/AGENTS.md"
printf '%s\n' 'project-specific skill' >"$CUSTOM/.agents/skills/skill-discovery/SKILL.md"
printf '%s\n' 'local learning customization' >>"$CUSTOM/.agents/skills/project-learning/SKILL.md"
"$ROOT/bin/agent-harness" init "$CUSTOM" >"$TMP/custom.log"
grep -q 'project-specific instructions' "$CUSTOM/AGENTS.md"
grep -q 'project-specific skill' "$CUSTOM/.agents/skills/skill-discovery/SKILL.md"
grep -q 'local learning customization' "$CUSTOM/.agents/skills/project-learning/SKILL.md"
grep -q 'project-learning/SKILL.md (modified/project-owned)' "$TMP/custom.log"
grep -q 'skill-discovery/SKILL.md (project-owned/customized' "$TMP/custom.log"
# Marker matching is NOT proof of ownership; historical heuristic deletes are gone.
printf '%s\n' 'check shared memory when `agent-memory` is available' >"$CUSTOM/AGENTS.md"
mkdir -p "$CUSTOM/docs" "$CUSTOM/scripts/agents"
printf '%s\n' 'legacy TencentDB Agent Memory orchestrator customized' >"$CUSTOM/docs/agent-orchestrator.md"
printf '%s\n' '# TencentDB Agent Memory custom helper' >"$CUSTOM/scripts/agents/agent-memory"
"$ROOT/bin/agent-harness" init "$CUSTOM" >/dev/null
grep -q 'check shared memory' "$CUSTOM/AGENTS.md"
test -f "$CUSTOM/docs/agent-orchestrator.md"
test -f "$CUSTOM/scripts/agents/agent-memory"

# Previous-install snapshot handles future unlisted generated AGENTS.md versions.
PREVIOUS="$TMP/previous-templates"
SNAPSHOT="$TMP/snapshot"
mkdir -p "$PREVIOUS/.agents/skills/shared-memory" "$SNAPSHOT/.agents/skills/shared-memory"
printf '%s\n' 'previous harness AGENTS template' > "$PREVIOUS/AGENTS.md"
cp "$PREVIOUS/AGENTS.md" "$SNAPSHOT/AGENTS.md"
printf '%s\n' 'previous harness generic skill' >"$PREVIOUS/.agents/skills/shared-memory/SKILL.md"
cp "$PREVIOUS/.agents/skills/shared-memory/SKILL.md" "$SNAPSHOT/.agents/skills/shared-memory/SKILL.md"
AGENT_HARNESS_PREVIOUS_TEMPLATES="$PREVIOUS" "$ROOT/bin/agent-harness" init "$SNAPSHOT" >"$TMP/snapshot.log"
cmp "$ROOT/templates/AGENTS.md" "$SNAPSHOT/AGENTS.md"
cmp "$ROOT/templates/.agents/skills/project-learning/SKILL.md" "$SNAPSHOT/.agents/skills/project-learning/SKILL.md"
assert_no_generic_skills "$SNAPSHOT"
grep -q '^MIGRATE .*AGENTS.md (untouched managed template)$' "$TMP/snapshot.log"

# Do not follow symlinks even when they point at an old generated template.
LINK="$TMP/link-project"
mkdir -p "$LINK"
printf '%s\n' 'project-controlled target' >"$TMP/external"
ln -s "$TMP/external" "$LINK/AGENTS.md"
"$ROOT/bin/agent-harness" init "$LINK" >"$TMP/link.log"
test -L "$LINK/AGENTS.md"
grep -q 'project-controlled target' "$TMP/external"
grep -q '(symlink/project-owned)' "$TMP/link.log"

# No legacy orchestration or bridge runtimes may reappear.
for path in scripts/orchestrate.mjs scripts/orchestrator/core.mjs scripts/agy-runner.mjs scripts/test-orchestrator.sh scripts/setup/chatgpt-web-control.sh scripts/setup/install-chatgpt-web.sh; do
  test ! -e "$ROOT/$path"
done
test -f "$ROOT/templates/.agents/skills/project-learning/SKILL.md"
test "$(find "$ROOT/templates/.agents/skills" -name SKILL.md | wc -l)" -eq 1

AGENT_HARNESS_NONINTERACTIVE=1 "$ROOT/bin/agent-harness" ready "$REPO" --core-only --non-interactive >/dev/null
"$ROOT/bin/agent-harness" --help >/dev/null
"$ROOT/bin/agent-harness" memory --help >/dev/null
"$ROOT/bin/agent-memory" --help >/dev/null
if "$ROOT/bin/agent-harness" chatgpt-web status >/dev/null 2>&1; then
  echo "retired web bridge should fail closed" >&2
  exit 1
fi
python3 "$ROOT/scripts/route_agent.py" --difficulty easy --domain backend |
  grep -q '"decision": "stay_local"'
python3 -m unittest discover -s "$ROOT/scripts" -p 'test_route_agent.py'

# Mock Orca validates exact delegation to upstream skills (no competing runtime).
MOCK_BIN="$TMP/mock-bin"
MOCK_LOG="$TMP/orca.log"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/orca" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_ORCA_LOG:?}"
case "${1:-}" in
  status|open) printf '%s\n' '{"ok":true}' ;;
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
env "${ORCA_ENV[@]}" "$ROOT/bin/agent-harness" orca guide |
  grep -q 'Orca live orchestration guide'
env "${ORCA_ENV[@]}" "$ROOT/bin/agent-harness" orca update >/dev/null
grep -q '^skills install --skill orca-cli --skill orchestration --skill computer-use$' "$MOCK_LOG"
grep -q '^skills update --all$' "$MOCK_LOG"

# Opt-in daily updater writes only its own systemd user units and is reversible.
cat > "$MOCK_BIN/systemctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_SYSTEMCTL_LOG:?}"
if [[ "${2:-}" == "is-enabled" ]]; then echo enabled; fi
MOCK
chmod +x "$MOCK_BIN/systemctl"
AUTO_ENV=( "${ORCA_ENV[@]}" HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/config" MOCK_SYSTEMCTL_LOG="$TMP/systemctl.log" )
env "${AUTO_ENV[@]}" "$ROOT/bin/agent-harness" orca auto-update enable >/dev/null
UNIT_DIR="$TMP/config/systemd/user"
test -f "$UNIT_DIR/agent-harness-orca-skills.service"
test -f "$UNIT_DIR/agent-harness-orca-skills.timer"
grep -q 'Environment="ORCA_CLI_COMMAND=' "$UNIT_DIR/agent-harness-orca-skills.service"
grep -q 'Environment="PATH=' "$UNIT_DIR/agent-harness-orca-skills.service"
grep -q '^OnCalendar=daily$' "$UNIT_DIR/agent-harness-orca-skills.timer"
env "${AUTO_ENV[@]}" "$ROOT/bin/agent-harness" orca auto-update status | grep -q enabled
env "${AUTO_ENV[@]}" "$ROOT/bin/agent-harness" orca auto-update disable >/dev/null
test ! -e "$UNIT_DIR/agent-harness-orca-skills.service"
test ! -e "$UNIT_DIR/agent-harness-orca-skills.timer"
# Do not overwrite a file with the same name that belongs to the user.
printf '%s\n' '# user-managed unit' >"$UNIT_DIR/agent-harness-orca-skills.service"
if env "${AUTO_ENV[@]}" "$ROOT/bin/agent-harness" orca auto-update enable >/dev/null 2>&1; then
  echo "Auto-updater overwrote a project-owned unit" >&2
  exit 1
fi
grep -q 'user-managed unit' "$UNIT_DIR/agent-harness-orca-skills.service"

# Legacy command names cannot silently start old runtimes.
if "$ROOT/bin/agent-harness" orchestrate status >/dev/null 2>&1; then exit 1; fi
if "$ROOT/bin/agent-harness" agy status >/dev/null 2>&1; then exit 1; fi

# Config and memory persistence remain outside the repository.
test "$("$ROOT/bin/agent-harness" version)" = "$(cat "$ROOT/VERSION")"
grep -q 'PREVIOUS_TEMPLATES=' "$ROOT/bootstrap.sh"
grep -q 'managed-template-hashes.tsv' "$ROOT/bin/agent-harness"
grep -q 'export AGENTMEMORY_DATA_DIR="$DATA_ROOT"' "$ROOT/scripts/setup/agentmemory-service.sh"
grep -q 'export AGENTMEMORY_DATA_DIR="$DATA_ROOT"' "$ROOT/scripts/setup/install-agentmemory.sh"
DATA_DIR="$(HOME="$TMP/home" XDG_DATA_HOME="$TMP/data" "$ROOT/bin/agent-harness" memory data-dir)"
test "$DATA_DIR" = "$TMP/data/agentmemory"
test ! -e "$REPO/data"

echo "Harness smoke test passed."
