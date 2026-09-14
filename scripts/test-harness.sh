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
test -f "$TMP/.agents/skills/repository-orchestrator/SKILL.md"
grep -q 'agent-harness orchestrate start' "$TMP/.agents/skills/repository-orchestrator/SKILL.md"
test -f "$TMP/.agents/skills/shared-memory/SKILL.md"
grep -q 'agentmemory' "$TMP/.agents/skills/shared-memory/SKILL.md"
grep -q '^## Repository orchestration' "$TMP/AGENTS.md"
grep -q 'repository-orchestrator' "$TMP/AGENTS.md"
grep -q 'Do not use native `create agent`' "$TMP/AGENTS.md"
test ! -e "$TMP/docs/agent-orchestrator.md"
test ! -e "$ROOT/templates/docs/chatgpt-orchestrator.md"
test ! -e "$TMP/scripts/agents/agent-memory"
test ! -e "$TMP/.agent-harness-version"
test ! -e "$TMP/.github/ISSUE_TEMPLATE/agent-task.md"
test ! -e "$TMP/.github/pull_request_template.md"
test ! -e "$ROOT/templates/.github/ISSUE_TEMPLATE/agent-task.md"
test ! -e "$ROOT/templates/.github/pull_request_template.md"
! grep -q 'copy_if_missing .*\.github' "$ROOT/bin/agent-harness"
! grep -q 'check "\.github/' "$ROOT/bin/agent-harness"
! grep -q 'templates/docs/chatgpt-orchestrator' "$ROOT/bin/agent-harness"
grep -q 'obsolete generated template' "$ROOT/bin/agent-harness"
test "$("$ROOT/bin/agent-harness" version)" = "$(cat "$ROOT/VERSION")"

# The dispatcher contract is Codex + Antigravity (agy), not Gemini CLI.
grep -q "SUPPORTED_AGENTS = new Set(\['codex', 'agy'\])" "$ROOT/scripts/orchestrator/core.mjs"
! grep -q "command -v gemini" "$ROOT/scripts/setup/install-ponytail.sh"
! grep -q "connect gemini-cli" "$ROOT/scripts/setup/install-agentmemory.sh"

mkdir -p "$TMP/docs"
printf '%s\n' 'project-owned orchestration notes' > "$TMP/docs/agent-orchestrator.md"
"$ROOT/bin/agent-harness" init "$TMP" >/dev/null
grep -q 'project-owned orchestration notes' "$TMP/docs/agent-orchestrator.md"
rm -f "$TMP/docs/agent-orchestrator.md"

printf '%s\n' 'check shared memory when `agent-memory` is available' > "$TMP/AGENTS.md"
printf '%s\n' 'legacy TencentDB Agent Memory skill' > "$TMP/.agents/skills/shared-memory/SKILL.md"
printf '%s\n' 'legacy TencentDB Agent Memory orchestrator' > "$TMP/docs/agent-orchestrator.md"
printf '%s\n' '# TencentDB Agent Memory legacy helper' > "$TMP/scripts/agents/agent-memory"
"$ROOT/bin/agent-harness" init "$TMP" >"$MIGRATION_LOG"
grep -q '^MIGRATE ' "$MIGRATION_LOG"
grep -q '^REMOVE  ' "$MIGRATION_LOG"
grep -q 'agentmemory' "$TMP/AGENTS.md"
grep -q '^## Repository orchestration' "$TMP/AGENTS.md"
grep -q 'repository-orchestrator' "$TMP/AGENTS.md"
! grep -q 'TencentDB Agent Memory' "$TMP/.agents/skills/shared-memory/SKILL.md"
test ! -e "$TMP/docs/agent-orchestrator.md"
test ! -e "$TMP/scripts/agents/agent-memory"

AGENT_HARNESS_NONINTERACTIVE=1 \
  "$ROOT/bin/agent-harness" ready "$TMP" --core-only --non-interactive >/dev/null

"$ROOT/bin/agent-harness" --help >/dev/null
"$ROOT/bin/agent-harness" chatgpt-web --help >/dev/null
"$ROOT/bin/agent-harness" memory --help >/dev/null
"$ROOT/bin/agent-memory" --help >/dev/null

grep -q 'OLD_AGENTS_BLOBS' "$ROOT/bootstrap.sh"
grep -q '41adcfaf38b6ca2b8b9c2ec6005f4f75fb16832e' "$ROOT/bootstrap.sh"
grep -q 'bc52e816056d09a119d7680039055a3b1f59e0a0' "$ROOT/bootstrap.sh"
grep -q 'current orchestration routing' "$ROOT/bootstrap.sh"

grep -q 'OLD_ORCHESTRATOR_SKILL_BLOBS' "$ROOT/bootstrap.sh"
grep -q 'b8c258d37ec997437e161aa9ea148290b5715a10' "$ROOT/bootstrap.sh"
grep -q 'bad3fbc6f77b2ef7f1c1448c85b36a7ae13b378e' "$ROOT/bootstrap.sh"
grep -q 'current dispatcher runtime' "$ROOT/bootstrap.sh"

grep -q 'remove_generated_orchestrator_doc' "$ROOT/bin/agent-harness"
grep -q '7536e45d9a3a2759b3235dc51ba0f490e3f4c128' "$ROOT/bin/agent-harness"

grep -q 'SERVICE_SCRIPT=.*agentmemory-service.sh' "$ROOT/scripts/setup/install-agentmemory.sh"
grep -q 'bash "$SERVICE_SCRIPT" start' "$ROOT/scripts/setup/install-agentmemory.sh"
grep -q 'nohup env CI=1 AGENTMEMORY_DATA_DIR="$DATA_ROOT" npx -y "$PACKAGE"' "$ROOT/scripts/setup/agentmemory-service.sh"
if grep -Eq '^[[:space:]]*CI=1 npx -y "\$PACKAGE"[[:space:]]*$' "$ROOT/scripts/setup/install-agentmemory.sh"; then
  echo "install-agentmemory.sh must not run the long-lived worker in foreground" >&2
  exit 1
fi

grep -q 'export AGENTMEMORY_DATA_DIR="$DATA_ROOT"' "$ROOT/scripts/setup/agentmemory-service.sh"
grep -q 'export AGENTMEMORY_DATA_DIR="$DATA_ROOT"' "$ROOT/scripts/setup/install-agentmemory.sh"
grep -q 'Legacy repo-local agentmemory data detected' "$ROOT/scripts/setup/install-agentmemory.sh"
DATA_DIR_OUTPUT="$(HOME="$TMP/home" XDG_DATA_HOME="$TMP/xdg-data" "$ROOT/bin/agent-harness" memory data-dir)"
test "$DATA_DIR_OUTPUT" = "$TMP/xdg-data/agentmemory"
test ! -e "$TMP/data"

if grep -Eq 'ln[[:space:]]+-s[f]?[[:space:]].*agent-harness' "$ROOT/bootstrap.sh"; then
  echo "bootstrap.sh must not symlink agent-harness into the bin directory" >&2
  exit 1
fi
grep -q 'rm -f "$BIN_DIR/agent-harness"' "$ROOT/bootstrap.sh"
grep -q 'exec %q' "$ROOT/bootstrap.sh"
grep -q 'chmod 0755 "$BIN_DIR/agent-harness"' "$ROOT/bootstrap.sh"

WRAPPER_DIR="$TMP/local-bin"
mkdir -p "$WRAPPER_DIR"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf 'exec %q "$@"\n' "$ROOT/bin/agent-harness"
} > "$WRAPPER_DIR/agent-harness"
chmod 0755 "$WRAPPER_DIR/agent-harness"
"$WRAPPER_DIR/agent-harness" chatgpt-web --help >/dev/null
"$WRAPPER_DIR/agent-harness" memory --help >/dev/null

echo "Harness smoke test passed."
