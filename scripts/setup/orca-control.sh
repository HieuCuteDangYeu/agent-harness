#!/usr/bin/env bash
set -euo pipefail

warn() { printf 'WARN    %s\n' "$*" >&2; }
ok() { printf 'OK      %s\n' "$*"; }

resolve_orca() {
  if [[ -n "${ORCA_CLI_COMMAND:-}" ]]; then
    if [[ -x "$ORCA_CLI_COMMAND" ]]; then
      printf '%s\n' "$ORCA_CLI_COMMAND"
      return 0
    fi
    if command -v "$ORCA_CLI_COMMAND" >/dev/null 2>&1; then
      command -v "$ORCA_CLI_COMMAND"
      return 0
    fi
  fi

  local candidate
  for candidate in orca-dev orca-ide orca; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}

usage() {
  cat <<'USAGE'
agent-harness orca <path|status|open|setup|update|guide|doctor>

path    Print the resolved Orca CLI executable.
status  Query the running Orca runtime as JSON.
open    Open/start Orca and return JSON status.
setup   Install Orca's core agent skills; also install Android emulator skill when adb exists.
update  Update already-installed Orca skills.
guide   Print the live version-matched Orca orchestration guide.
doctor  Verify CLI discovery, orchestration guide availability, and runtime reachability.
USAGE
}

ORCA="$(resolve_orca || true)"
if [[ -z "$ORCA" ]]; then
  echo "ERROR   Orca CLI not found. Install Orca from https://www.onorca.dev/docs/install and register its CLI." >&2
  exit 127
fi

COMMAND="${1:-status}"
shift || true

case "$COMMAND" in
  path)
    printf '%s\n' "$ORCA"
    ;;
  status)
    exec "$ORCA" status --json "$@"
    ;;
  open)
    exec "$ORCA" open --json "$@"
    ;;
  setup)
    "$ORCA" skills install --skill orca-cli --skill orchestration
    if command -v adb >/dev/null 2>&1; then
      "$ORCA" skills install --skill orca-emulator-android || warn "Could not install Orca Android emulator skill"
    fi
    ok "Orca agent skills installed"
    ;;
  update)
    exec "$ORCA" skills update --all "$@"
    ;;
  guide)
    exec "$ORCA" skills get orchestration --full "$@"
    ;;
  doctor)
    ok "Orca CLI: $ORCA"
    if "$ORCA" skills get orchestration --full >/dev/null 2>&1; then
      ok "Orca orchestration guide available"
    else
      echo "ERROR   Orca orchestration guide is unavailable; run 'agent-harness orca setup'." >&2
      exit 1
    fi
    if "$ORCA" status --json >/dev/null 2>&1; then
      ok "Orca runtime reachable"
    else
      echo "ERROR   Orca runtime is not reachable; run 'agent-harness orca open'." >&2
      exit 1
    fi
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    echo "Unknown Orca command: $COMMAND" >&2
    usage >&2
    exit 2
    ;;
esac
