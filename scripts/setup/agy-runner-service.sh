#!/usr/bin/env bash
set -euo pipefail

HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/agent-harness/agy"
QUEUE_ROOT="${AGENT_HARNESS_AGY_QUEUE_DIR:-/tmp/agent-harness-agy-$(id -u)}"
PID_FILE="$STATE_ROOT/runner.pid"
LOG_FILE="$STATE_ROOT/runner.log"
RUNNER="$HARNESS_ROOT/scripts/agy-runner.mjs"

mkdir -p "$STATE_ROOT" "$QUEUE_ROOT"
chmod 700 "$STATE_ROOT" "$QUEUE_ROOT" 2>/dev/null || true

alive() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

start() {
  if alive; then
    echo "OK      agy host runner already running (pid=$(cat "$PID_FILE"))"
    echo "QUEUE   $QUEUE_ROOT"
    return 0
  fi
  command -v node >/dev/null 2>&1 || { echo "ERROR   node is required" >&2; return 127; }
  command -v agy >/dev/null 2>&1 || { echo "ERROR   agy is not installed or not on PATH" >&2; return 127; }
  rm -f "$PID_FILE" "$QUEUE_ROOT/runner.json"
  nohup env AGENT_HARNESS_AGY_QUEUE_DIR="$QUEUE_ROOT" node "$RUNNER" serve >>"$LOG_FILE" 2>&1 </dev/null &
  local pid=$!
  printf '%s\n' "$pid" > "$PID_FILE"
  for _ in $(seq 1 30); do
    if [[ -f "$QUEUE_ROOT/runner.json" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "OK      agy host runner started (pid=$pid)"
      echo "QUEUE   $QUEUE_ROOT"
      echo "LOG     $LOG_FILE"
      return 0
    fi
    sleep 0.2
  done
  echo "ERROR   agy host runner failed to become ready; see $LOG_FILE" >&2
  return 1
}

stop() {
  if ! alive; then
    rm -f "$PID_FILE" "$QUEUE_ROOT/runner.json"
    echo "OK      agy host runner already stopped"
    return 0
  fi
  local pid
  pid="$(cat "$PID_FILE")"
  kill "$pid" 2>/dev/null || true
  for _ in $(seq 1 20); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.2
  done
  if kill -0 "$pid" 2>/dev/null; then kill -9 "$pid" 2>/dev/null || true; fi
  rm -f "$PID_FILE" "$QUEUE_ROOT/runner.json"
  echo "OK      agy host runner stopped"
}

status() {
  if alive && [[ -f "$QUEUE_ROOT/runner.json" ]]; then
    echo "OK      agy host runner running (pid=$(cat "$PID_FILE"))"
    echo "QUEUE   $QUEUE_ROOT"
    echo "LOG     $LOG_FILE"
    return 0
  fi
  echo "STOPPED agy host runner"
  echo "QUEUE   $QUEUE_ROOT"
  return 1
}

doctor() {
  status >/dev/null || {
    echo "ERROR   agy host runner is not running. Start it from a normal terminal with: agent-harness agy start" >&2
    return 1
  }
  local job_id result_file status_value response
  job_id="doctor-$(date +%s)-$$"
  result_file="$QUEUE_ROOT/results/$job_id.json"
  mkdir -p "$QUEUE_ROOT/pending" "$QUEUE_ROOT/results"
  node - "$QUEUE_ROOT/pending/$job_id.json" "$job_id" "$PWD" <<'NODE'
const fs = require('fs');
const [file, id, cwd] = process.argv.slice(2);
fs.writeFileSync(file, JSON.stringify({
  version: 1,
  id,
  cwd,
  prompt: 'Reply exactly AGY_OK',
  model: null,
  approval: null,
  timeout: '30s',
  taskId: 'doctor',
}, null, 2) + '\n', { mode: 0o600 });
NODE
  for _ in $(seq 1 180); do
    if [[ -f "$result_file" ]]; then
      status_value="$(node -e 'const d=require(process.argv[1]); process.stdout.write(d.status||"")' "$result_file")"
      response="$(node -e 'const d=require(process.argv[1]); process.stdout.write((d.response||"").trim())' "$result_file")"
      rm -f "$result_file"
      if [[ "$status_value" == "success" && "$response" == "AGY_OK" ]]; then
        echo "OK      agy host runner smoke test passed"
        return 0
      fi
      echo "ERROR   agy host runner smoke test failed (status=$status_value response=$response)" >&2
      return 1
    fi
    sleep 0.25
  done
  echo "ERROR   agy host runner smoke test timed out" >&2
  return 1
}

case "${1:-status}" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  status) status ;;
  doctor) doctor ;;
  logs) tail -n "${2:-100}" "$LOG_FILE" 2>/dev/null || true ;;
  queue-dir) printf '%s\n' "$QUEUE_ROOT" ;;
  *) echo "Usage: agent-harness agy <start|stop|restart|status|doctor|logs|queue-dir>" >&2; exit 2 ;;
esac
