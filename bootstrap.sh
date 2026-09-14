#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${AGENT_HARNESS_REPO_URL:-https://github.com/HieuCuteDangYeu/agent-harness.git}"
INSTALL_DIR="${AGENT_HARNESS_HOME:-$HOME/.local/share/agent-harness}"
BIN_DIR="${AGENT_HARNESS_BIN_DIR:-$HOME/.local/bin}"
TARGET="${AGENT_HARNESS_TARGET:-$PWD}"

command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 127; }

mkdir -p "$(dirname "$INSTALL_DIR")" "$BIN_DIR"

if [[ -d "$INSTALL_DIR/.git" ]]; then
  echo "Updating agent-harness at $INSTALL_DIR"
  git -C "$INSTALL_DIR" fetch --quiet origin main
  git -C "$INSTALL_DIR" checkout --quiet main
  git -C "$INSTALL_DIR" reset --quiet --hard origin/main
else
  if [[ -e "$INSTALL_DIR" ]]; then
    echo "Refusing to replace non-Git path: $INSTALL_DIR" >&2
    exit 1
  fi
  echo "Installing agent-harness into $INSTALL_DIR"
  git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

rm -f "$BIN_DIR/agent-harness"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'set -euo pipefail'
  printf '%s\n' 'if [[ "${1:-}" == "orchestrate" ]]; then'
  printf '%s\n' '  shift'
  printf '  exec node %q "$@"\n' "$INSTALL_DIR/scripts/orchestrate.mjs"
  printf '%s\n' 'fi'
  printf 'exec %q "$@"\n' "$INSTALL_DIR/bin/agent-harness"
} > "$BIN_DIR/agent-harness"
chmod 0755 "$BIN_DIR/agent-harness"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "NOTE: $BIN_DIR is not currently on PATH; the bootstrap will run by absolute path now."
fi

"$INSTALL_DIR/bin/agent-harness" ready "$TARGET" "$@"

# Refresh only exact untouched generated contracts. Repository-owned edits are preserved.
AGENTS_FILE="$TARGET/AGENTS.md"
OLD_AGENTS_BLOBS=(
  "41adcfaf38b6ca2b8b9c2ec6005f4f75fb16832e" # v0.4.x-v0.6.0
  "bc52e816056d09a119d7680039055a3b1f59e0a0" # v0.6.1
  "690cc85979bf15c3aa99468a34f30618155b3fa8" # v0.6.2-v0.6.5
  "74a3955795a1bc303bd03bcb173b56f99718ce19" # v0.7.0
)
if [[ -f "$AGENTS_FILE" ]]; then
  current_blob="$(git hash-object "$AGENTS_FILE" 2>/dev/null || true)"
  for old_blob in "${OLD_AGENTS_BLOBS[@]}"; do
    if [[ "$current_blob" == "$old_blob" ]]; then
      cp "$INSTALL_DIR/templates/AGENTS.md" "$AGENTS_FILE"
      echo "MIGRATE $AGENTS_FILE (current orchestration routing)"
      break
    fi
  done
fi

ORCHESTRATOR_SKILL="$TARGET/.agents/skills/repository-orchestrator/SKILL.md"
OLD_ORCHESTRATOR_SKILL_BLOBS=(
  "b8c258d37ec997437e161aa9ea148290b5715a10" # v0.6.2
  "bad3fbc6f77b2ef7f1c1448c85b36a7ae13b378e" # v0.6.3
  "fdd49c1743c6c7866cb43ea9b3f88771f95e30b0" # v0.6.4
  "bdbd44332809943b596dad4a85a11b073bfc7fa1" # v0.6.5
  "442d129575564554ed6a4f256cc31f114b35e7ae" # v0.7.0
)
if [[ -f "$ORCHESTRATOR_SKILL" ]]; then
  current_blob="$(git hash-object "$ORCHESTRATOR_SKILL" 2>/dev/null || true)"
  for old_blob in "${OLD_ORCHESTRATOR_SKILL_BLOBS[@]}"; do
    if [[ "$current_blob" == "$old_blob" ]]; then
      cp "$INSTALL_DIR/templates/.agents/skills/repository-orchestrator/SKILL.md" "$ORCHESTRATOR_SKILL"
      echo "MIGRATE $ORCHESTRATOR_SKILL (current host-runner runtime)"
      break
    fi
  done
fi

# init/ready removes only known generated legacy files. User-edited project files are preserved.
