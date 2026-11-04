#!/usr/bin/env bash
set -euo pipefail

PACKAGE="@agentmemory/agentmemory@latest"
BASE_URL="${AGENTMEMORY_URL:-http://127.0.0.1:3111}"
ENV_DIR="$HOME/.agentmemory"
ENV_FILE="$ENV_DIR/.env"
SERVICE_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/agentmemory-service.sh"

case "$(uname -s)" in
  Darwin) DEFAULT_DATA_ROOT="$HOME/Library/Application Support/agentmemory" ;;
  *) DEFAULT_DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/agentmemory" ;;
esac
DATA_ROOT="${AGENTMEMORY_DATA_DIR:-$DEFAULT_DATA_ROOT}"
export AGENTMEMORY_DATA_DIR="$DATA_ROOT"

env_changed=0

warn() { printf 'WARN    %s\n' "$*" >&2; }
ok() { printf 'OK      %s\n' "$*"; }

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "$1 is required for agentmemory setup" >&2
    exit 127
  }
}

for cmd in node npm npx curl sh tar; do
  need "$cmd"
done

node_major="$(node -p 'Number(process.versions.node.split(".")[0])')"
if [[ "$node_major" -lt 20 ]]; then
  echo "agentmemory requires Node.js 20 or newer; found $(node -v)" >&2
  exit 2
fi
ok "Node $(node -v)"

mkdir -p "$ENV_DIR" "$DATA_ROOT"
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

ensure_env() {
  local key="$1"
  local value="$2"
  if grep -Eq "^[[:space:]]*${key}=" "$ENV_FILE"; then
    ok "$key already configured"
  else
    printf '\n%s=%s\n' "$key" "$value" >> "$ENV_FILE"
    env_changed=1
    ok "$key=$value"
  fi
}

# No cloud LLM key is required. Local MiniLM embeddings give semantic recall;
# the lean core tool set keeps MCP/tool context small.
ensure_env EMBEDDING_PROVIDER local
ensure_env AGENTMEMORY_TOOLS core
ok "agentmemory data directory: $DATA_ROOT"

if [[ -f "$PWD/data/state_store.db" || -f "$PWD/data/iii-config.yaml" ]]; then
  warn "Legacy repo-local agentmemory data detected at $PWD/data"
  warn "The harness will use $DATA_ROOT instead. Inspect/migrate the old data before deleting it."
fi

if [[ "$env_changed" -eq 1 ]] && curl -fsS --max-time 2 "$BASE_URL/agentmemory/livez" >/dev/null 2>&1; then
  echo "Restarting agentmemory so new local defaults take effect..."
  bash "$SERVICE_SCRIPT" restart
else
  bash "$SERVICE_SCRIPT" start
fi

# One capture implementation per host. Codex native plugin supplies its own
# MCP + hooks; do not ALSO install global connect --with-hooks (duplicate events).
if command -v codex >/dev/null 2>&1; then
  echo "Installing agentmemory Codex plugin (MCP + native lifecycle hooks)..."
  codex plugin marketplace add rohitg00/agentmemory >/dev/null 2>&1 || true
  if codex plugin add agentmemory@agentmemory; then
    ok "Codex plugin installed; review and trust hooks in /hooks"
  else
    warn "Codex plugin may already be installed or unavailable. Check /hooks and the MCP list."
    warn "For unsupported plugin hosts, run 'agent-harness memory connect codex' for MCP-only wiring."
  fi
fi

if command -v agy >/dev/null 2>&1; then
  echo "Connecting Antigravity CLI to agentmemory..."
  if [[ "${AGENT_HARNESS_MEMORY_CAPTURE:-0}" == "1" ]]; then
    CI=1 npx -y "$PACKAGE" connect antigravity-cli --with-hooks ||
      warn "Could not configure Antigravity auto-capture; inspect current hooks before retrying."
  else
    CI=1 npx -y "$PACKAGE" connect antigravity-cli ||
      warn "Could not configure Antigravity MCP."
  fi
fi

cat <<NEXT

agentmemory is ready in keyless mode and runs detached from this terminal.

No cloud LLM API key is required.
Defaults selected by agent-harness when those settings were not already configured:
  - local semantic embeddings: Xenova/all-MiniLM-L6-v2
  - MCP tool surface: core (8 tools)
  - automatic LLM compression: off
  - LLM compression: opt-in; recorded events and memory retrieval depend on each agent's native hooks
  - never enable both Codex plugin hooks and global connect --with-hooks
  - persistent data directory: $DATA_ROOT

Local endpoints:
  REST / MCP: http://127.0.0.1:3111
  Viewer:     http://127.0.0.1:3113

Lifecycle:
  agent-harness memory status
  agent-harness memory data-dir
  agent-harness memory restart
  agent-harness memory logs
  agent-harness memory viewer

The first semantic-memory request downloads the local MiniLM model once.
Restart configured agents after setup and verify capture in the agentmemory viewer.
For additional CLI agents use: agent-harness memory connect <supported-agent> [--with-hooks]
Consult upstream adapter docs; do not install duplicate hook routes.
For long-term learning, promote only validated lessons or project-specific invariants.
NEXT
