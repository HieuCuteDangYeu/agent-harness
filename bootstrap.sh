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

# Do not symlink the CLI into ~/.local/bin. Besides keeping helper paths stable,
# this wrapper provides the Node-based orchestration command without complicating
# the existing Bash lifecycle CLI.
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

# Migrate only exact generated orchestrator documents from older harness
# versions. Never overwrite a user-edited copy.
ORCHESTRATOR_FILE="$TARGET/docs/agent-orchestrator.md"
OLD_ORCHESTRATOR_BLOBS=(
  "25d3eac348f367c261a74cb381a276afe9066694" # v0.4.x
  "5c5a38f6a330c1ac22055ab2c5bc37a92450e2b1" # v0.5.0
)
if [[ -f "$ORCHESTRATOR_FILE" ]]; then
  current_blob="$(git hash-object "$ORCHESTRATOR_FILE" 2>/dev/null || true)"
  for old_blob in "${OLD_ORCHESTRATOR_BLOBS[@]}"; do
    if [[ "$current_blob" == "$old_blob" ]]; then
      cp "$INSTALL_DIR/templates/docs/chatgpt-orchestrator.md" "$ORCHESTRATOR_FILE"
      echo "MIGRATE $ORCHESTRATOR_FILE (current orchestrator protocol)"
      break
    fi
  done
fi
