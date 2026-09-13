#!/usr/bin/env bash
set -euo pipefail

PACKAGE="@agentmemory/agentmemory@latest"
BASE_URL="${AGENTMEMORY_URL:-http://127.0.0.1:3111}"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/agent-harness/agentmemory"
PID_FILE="$STATE_ROOT/service.pid"
LOG_FILE="$STATE_ROOT/service.log"

case "$(uname -s)" in
  Darwin) DEFAULT_DATA_ROOT="$HOME/Library/Application Support/agentmemory" ;;
  *) DEFAULT_DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/agentmemory" ;;
esac
DATA_ROOT="${AGENTMEMORY_DATA_DIR:-$DEFAULT_DATA_ROOT}"
export AGENTMEMORY_DATA_DIR="$DATA_ROOT"

mkdir -p "$STATE_ROOT" "$DATA_ROOT"

ok() { printf 'OK      %s\n' "$*"; }
warn() { printf 'WARN    %s\n' "$*" >&2; }

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "$1 is required" >&2
    exit 127
  }
}

healthy() {
  command -v curl >/dev/null 2>&1 && \
    curl -fsS --max-time 2 "$BASE_URL/agentmemory/livez" >/dev/null 2>&1
}

tracked_pid() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$pid"
}

tracked_running() {
  local pid
  pid="$(tracked_pid 2>/dev/null || true)"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

start_service() {
  need node
  need npx
  need curl

  if healthy; then
    ok "agentmemory already healthy at $BASE_URL"
    echo "INFO    data directory: $DATA_ROOT"
    return 0
  fi

  if tracked_running; then
    warn "Tracked agentmemory process is running but health is not ready yet."
  else
    rm -f "$PID_FILE"
    : > "$LOG_FILE"
    echo "Starting agentmemory in the background..."
    echo "Data directory: $DATA_ROOT"
    nohup env CI=1 AGENTMEMORY_DATA_DIR="$DATA_ROOT" npx -y "$PACKAGE" >>"$LOG_FILE" 2>&1 </dev/null &
    local pid=$!
    printf '%s\n' "$pid" > "$PID_FILE"
    ok "started agentmemory process pid=$pid"
  fi

  local i pid
  for ((i = 1; i <= 120; i++)); do
    if healthy; then
      ok "agentmemory healthy at $BASE_URL"
      return 0
    fi

    pid="$(tracked_pid 2>/dev/null || true)"
    if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
      warn "agentmemory process exited before becoming healthy."
      tail -n 40 "$LOG_FILE" >&2 || true
      rm -f "$PID_FILE"
      return 1
    fi

    if (( i % 10 == 0 )); then
      echo "Waiting for agentmemory... ${i}s"
    fi
    sleep 1
  done

  warn "agentmemory did not become healthy within 120 seconds."
  echo "Inspect logs with: agent-harness memory logs" >&2
  tail -n 40 "$LOG_FILE" >&2 || true
  return 1
}

stop_service() {
  need npx

  local pid=""
  pid="$(tracked_pid 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "Stopping harness-managed agentmemory process pid=$pid..."
    kill "$pid" 2>/dev/null || true
    for _ in {1..10}; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.5
    done
    if kill -0 "$pid" 2>/dev/null; then
      warn "agentmemory process did not exit after SIGTERM; sending SIGKILL."
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$PID_FILE"

  # The upstream CLI owns the iii engine lifecycle. This is best-effort so a
  # missing/stale engine does not make `stop` itself fail.
  CI=1 npx -y "$PACKAGE" stop --force >/dev/null 2>&1 || true

  if healthy; then
    warn "agentmemory is still reachable. It may have been started outside agent-harness."
    return 1
  fi
  ok "agentmemory stopped"
}

status_service() {
  need curl
  echo "INFO    data directory: $DATA_ROOT"
  if healthy; then
    ok "agentmemory reachable at $BASE_URL"
    if tracked_running; then
      ok "harness-managed process pid=$(tracked_pid)"
    else
      echo "INFO    healthy process is not owned by this harness lifecycle wrapper"
    fi
    if command -v npx >/dev/null 2>&1; then
      CI=1 npx -y "$PACKAGE" status || true
    fi
    return 0
  fi

  warn "agentmemory is not reachable at $BASE_URL"
  if tracked_running; then
    warn "tracked process pid=$(tracked_pid) exists but health is unavailable"
  fi
  return 1
}

open_viewer() {
  healthy || {
    echo "agentmemory is not running. Start it with: agent-harness memory start" >&2
    exit 1
  }
  local url="http://127.0.0.1:3113"
  if command -v xdg-open >/dev/null 2>&1; then
    nohup xdg-open "$url" >/dev/null 2>&1 &
  elif command -v open >/dev/null 2>&1; then
    open "$url"
  else
    echo "$url"
    return 0
  fi
  ok "opened agentmemory viewer: $url"
}

show_logs() {
  local lines="${1:-100}"
  [[ "$lines" =~ ^[0-9]+$ ]] || { echo "logs line count must be an integer" >&2; exit 2; }
  if [[ ! -f "$LOG_FILE" ]]; then
    echo "No harness-managed agentmemory log exists yet: $LOG_FILE"
    exit 0
  fi
  tail -n "$lines" "$LOG_FILE"
}

usage() {
  cat <<'USAGE'
agent-harness memory start
agent-harness memory status
agent-harness memory stop
agent-harness memory restart
agent-harness memory logs [lines]
agent-harness memory viewer
agent-harness memory data-dir
agent-harness memory doctor [args...]
agent-harness memory upgrade [args...]

agent-harness starts agentmemory detached so project setup never occupies your
terminal. Persistent memory data is kept outside project repositories.
USAGE
}

command="${1:-status}"
if [[ $# -gt 0 ]]; then shift; fi

case "$command" in
  start)
    start_service
    ;;
  status)
    status_service
    ;;
  stop)
    stop_service
    ;;
  restart)
    stop_service || true
    start_service
    ;;
  logs)
    show_logs "${1:-100}"
    ;;
  viewer|open)
    open_viewer
    ;;
  data-dir)
    printf '%s\n' "$DATA_ROOT"
    ;;
  doctor)
    need npx
    exec npx -y "$PACKAGE" doctor "$@"
    ;;
  upgrade)
    need npx
    stop_service || true
    npx -y "$PACKAGE" upgrade "$@"
    start_service
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown memory command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
