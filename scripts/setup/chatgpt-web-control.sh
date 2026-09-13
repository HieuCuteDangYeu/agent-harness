#!/usr/bin/env bash
set -euo pipefail

INSTALLER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-chatgpt-web.sh"
CORE_HOME="${CODEX_CHATGPT_WEB_HOME:-$HOME/.codex-chatgpt-web}"
DESCRIPTOR="$CORE_HOME/runtime/launcher-browser.json"
LINUX_WRAPPER_DEFAULT="$HOME/.local/bin/codex-web-gpt"

ok() { printf 'OK      %s\n' "$*"; }
warn() { printf 'WARN    %s\n' "$*" >&2; }

linux_wrapper() {
  if command -v codex-web-gpt >/dev/null 2>&1; then
    command -v codex-web-gpt
  elif [[ -x "$LINUX_WRAPPER_DEFAULT" ]]; then
    printf '%s\n' "$LINUX_WRAPPER_DEFAULT"
  else
    return 1
  fi
}

mac_app() {
  if [[ -d "/Applications/Codex Web GPT.app" ]]; then
    printf '%s\n' "/Applications/Codex Web GPT.app"
  elif [[ -d "$HOME/Applications/Codex Web GPT.app" ]]; then
    printf '%s\n' "$HOME/Applications/Codex Web GPT.app"
  else
    return 1
  fi
}

installed() {
  case "$(uname -s)" in
    Linux) linux_wrapper >/dev/null 2>&1 ;;
    Darwin) mac_app >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

descriptor_pid() {
  [[ -f "$DESCRIPTOR" ]] || return 1
  local pid
  pid="$(sed -n 's/.*"pid"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$DESCRIPTOR" | head -n 1)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$pid"
}

running() {
  local pid
  pid="$(descriptor_pid 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  case "$(uname -s)" in
    Linux)
      pgrep -f 'Codex Web GPT\.AppImage|codex-web-gpt' >/dev/null 2>&1
      ;;
    Darwin)
      pgrep -x 'Codex Web GPT' >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

show_status() {
  if installed; then
    case "$(uname -s)" in
      Linux) ok "Codex Web GPT installed: $(linux_wrapper)" ;;
      Darwin) ok "Codex Web GPT installed: $(mac_app)" ;;
    esac
  else
    warn "Codex Web GPT launcher is not installed"
  fi

  if running; then
    local pid
    pid="$(descriptor_pid 2>/dev/null || true)"
    if [[ -n "$pid" ]]; then
      ok "Codex Web GPT running (pid=$pid)"
    else
      ok "Codex Web GPT running"
    fi
    return 0
  fi

  warn "Codex Web GPT is not running"
  installed
}

open_launcher() {
  if running; then
    ok "Codex Web GPT is already running"
    return 0
  fi

  case "$(uname -s)" in
    Linux)
      local wrapper
      wrapper="$(linux_wrapper 2>/dev/null || true)"
      [[ -n "$wrapper" ]] || {
        echo "Codex Web GPT is not installed. Run: agent-harness chatgpt-web repair" >&2
        exit 1
      }
      nohup "$wrapper" >/dev/null 2>&1 &
      ;;
    Darwin)
      local app
      app="$(mac_app 2>/dev/null || true)"
      [[ -n "$app" ]] || {
        echo "Codex Web GPT is not installed. Run: agent-harness chatgpt-web repair" >&2
        exit 1
      }
      open "$app"
      ;;
    *)
      echo "chatgpt-web open currently supports Linux and macOS." >&2
      exit 2
      ;;
  esac

  for _ in {1..20}; do
    if running; then
      ok "Codex Web GPT opened"
      return 0
    fi
    sleep 0.5
  done

  warn "Launcher command was started but Codex Web GPT did not report running yet."
  return 1
}

repair_launcher() {
  if running; then
    echo "Codex Web GPT is currently running." >&2
    echo "Quit the launcher first, then run: agent-harness chatgpt-web repair" >&2
    exit 2
  fi
  bash "$INSTALLER"
}

usage() {
  cat <<'USAGE'
agent-harness chatgpt-web status
agent-harness chatgpt-web open
agent-harness chatgpt-web repair

status  Show whether the launcher is installed and currently running.
open    Start the existing launcher without reinstalling it.
repair  Re-run the official upstream launcher installer. Quit the launcher first.
USAGE
}

command="${1:-status}"
case "$command" in
  status) show_status ;;
  open|start) open_launcher ;;
  repair|install|update) repair_launcher ;;
  help|-h|--help) usage ;;
  *)
    echo "Unknown chatgpt-web command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
