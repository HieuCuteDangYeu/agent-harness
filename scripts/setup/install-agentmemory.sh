#!/usr/bin/env bash
set -euo pipefail

PACKAGE="@agentmemory/agentmemory@latest"
BASE_URL="${AGENTMEMORY_URL:-http://127.0.0.1:3111}"
ENV_DIR="$HOME/.agentmemory"
ENV_FILE="$ENV_DIR/.env"

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

mkdir -p "$ENV_DIR"
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

ensure_env() {
  local key="$1"
  local value="$2"
  if grep -Eq "^[[:space:]]*${key}=" "$ENV_FILE"; then
    ok "$key already configured"
  else
    printf '\n%s=%s\n' "$key" "$value" >> "$ENV_FILE"
    ok "$key=$value"
  fi
}

# No cloud LLM key is required. Local MiniLM embeddings give semantic recall;
# the lean core tool set keeps MCP/tool context small.
ensure_env EMBEDDING_PROVIDER local
ensure_env AGENTMEMORY_TOOLS core

if curl -fsS --max-time 2 "$BASE_URL/agentmemory/livez" >/dev/null 2>&1; then
  ok "agentmemory already running at $BASE_URL"
else
  echo "Starting agentmemory in keyless mode..."
  # CI=1 deliberately skips the upstream first-run provider wizard. Upstream
  # records keyless defaults, starts the pinned iii engine, and backgrounds it.
  CI=1 npx -y "$PACKAGE"
fi

ready=0
for _ in $(seq 1 30); do
  if curl -fsS --max-time 2 "$BASE_URL/agentmemory/livez" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [[ "$ready" -ne 1 ]]; then
  warn "agentmemory did not become healthy at $BASE_URL within 30 seconds."
  echo "Run: npx -y $PACKAGE doctor" >&2
  exit 1
fi
ok "agentmemory REST/MCP healthy on :3111"

if command -v codex >/dev/null 2>&1; then
  echo "Wiring agentmemory into Codex..."
  codex plugin marketplace add rohitg00/agentmemory >/dev/null 2>&1 || true
  if codex plugin add agentmemory@agentmemory >/dev/null 2>&1; then
    ok "agentmemory Codex plugin installed"
  else
    warn "Codex plugin install returned non-zero; continuing with MCP wiring."
  fi
  if CI=1 npx -y "$PACKAGE" connect codex --with-hooks; then
    ok "agentmemory MCP/hooks wired into Codex"
  else
    warn "Codex hook wiring had warnings; retrying MCP-only wiring."
    CI=1 npx -y "$PACKAGE" connect codex || true
  fi
fi

if command -v agy >/dev/null 2>&1; then
  echo "Wiring agentmemory into Antigravity..."
  CI=1 npx -y "$PACKAGE" connect antigravity || warn "Antigravity wiring needs attention."
fi

if command -v gemini >/dev/null 2>&1; then
  echo "Wiring agentmemory into Gemini CLI..."
  CI=1 npx -y "$PACKAGE" connect gemini-cli || warn "Gemini CLI wiring needs attention."
fi

cat <<'NEXT'

agentmemory is ready in keyless mode.

No OpenAI/Gemini/Anthropic API key is required.
Defaults selected by agent-harness:
  - local semantic embeddings: Xenova/all-MiniLM-L6-v2
  - MCP tool surface: core (8 tools)
  - automatic LLM compression: off
  - automatic context injection: off unless you enable it yourself

Local endpoints:
  REST / MCP: http://127.0.0.1:3111
  Viewer:     http://127.0.0.1:3113

The first semantic-memory request downloads the local MiniLM model once.
Restart Codex / Gemini / Antigravity after setup so they reload MCP configuration.
Codex users should launch the Codex TUI once and review/trust the new hooks.
NEXT
