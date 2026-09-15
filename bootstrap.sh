#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${AGENT_HARNESS_REPO_URL:-https://github.com/HieuCuteDangYeu/agent-harness.git}"
INSTALL_DIR="${AGENT_HARNESS_HOME:-$HOME/.local/share/agent-harness}"
BIN_DIR="${AGENT_HARNESS_BIN_DIR:-$HOME/.local/bin}"
TARGET="${AGENT_HARNESS_TARGET:-$PWD}"
PREVIOUS_TEMPLATES=""

command -v git >/dev/null 2>&1 || { echo "git is required" >&2; exit 127; }

cleanup() {
  if [[ -n "$PREVIOUS_TEMPLATES" && -d "$PREVIOUS_TEMPLATES" ]]; then
    rm -rf "$PREVIOUS_TEMPLATES"
  fi
}
trap cleanup EXIT

mkdir -p "$(dirname "$INSTALL_DIR")" "$BIN_DIR"

if [[ -d "$INSTALL_DIR/.git" ]]; then
  # Preserve the exact template set from the previously installed harness before
  # moving the harness checkout. agent-harness can then safely refresh project
  # files only when they still match those untouched generated templates.
  PREVIOUS_TEMPLATES="$(mktemp -d)"
  if [[ -d "$INSTALL_DIR/templates" ]]; then
    cp -a "$INSTALL_DIR/templates/." "$PREVIOUS_TEMPLATES/"
  fi

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

retire_legacy_agy_runner() {
  local state_root="${XDG_STATE_HOME:-$HOME/.local/state}/agent-harness/agy"
  local pid_file="$state_root/runner.pid"
  [[ -f "$pid_file" ]] || return 0

  local pid args=""
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    if command -v ps >/dev/null 2>&1; then
      args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
    fi
    if [[ "$args" == *"agy-runner.mjs"* ]]; then
      kill "$pid" 2>/dev/null || true
      echo "STOP    legacy agent-harness agy runner (pid=$pid)"
    else
      echo "NOTE: legacy agy runner pid file exists but pid $pid was not identified as agent-harness; leaving process untouched."
    fi
  fi
  rm -f "$pid_file"
}

retire_legacy_agy_runner

rm -f "$BIN_DIR/agent-harness"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'set -euo pipefail'
  printf 'exec %q "$@"\n' "$INSTALL_DIR/bin/agent-harness"
} > "$BIN_DIR/agent-harness"
chmod 0755 "$BIN_DIR/agent-harness"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "NOTE: $BIN_DIR is not currently on PATH; the bootstrap will run by absolute path now."
fi

if [[ -n "$PREVIOUS_TEMPLATES" ]]; then
  AGENT_HARNESS_PREVIOUS_TEMPLATES="$PREVIOUS_TEMPLATES" \
    "$INSTALL_DIR/bin/agent-harness" ready "$TARGET" "$@"
else
  "$INSTALL_DIR/bin/agent-harness" ready "$TARGET" "$@"
fi

# Managed Markdown migration is owned by bin/agent-harness. It refreshes every
# untouched generated contract, preserves project-owned edits, uses the prior
# installed template snapshot for normal upgrades, and falls back to the
# historical hash catalog to repair installations skipped by older migrations.
