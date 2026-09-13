#!/usr/bin/env bash
set -euo pipefail

URL="https://github.com/miuuyy/codex-chatgpt-web/releases/latest/download/install-launcher.sh"

command -v curl >/dev/null 2>&1 || {
  echo "curl is required to download the upstream installer." >&2
  exit 127
}

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

curl -fsSL "$URL" -o "$TMP"
chmod 700 "$TMP"

echo "Downloaded upstream installer: $URL"
if command -v sha256sum >/dev/null 2>&1; then
  echo "Local installer SHA-256: $(sha256sum "$TMP" | awk '{print $1}')"
fi

echo "Executing the official upstream Codex Web GPT launcher installer..."
if ! sh "$TMP"; then
  cat >&2 <<'ERR'
Codex Web GPT installation/update failed.
If the launcher is currently running, quit it fully and retry:
  agent-harness chatgpt-web repair
ERR
  exit 1
fi

cat <<'NEXT'
Machine-side install finished.

Launcher lifecycle:
  agent-harness chatgpt-web status
  agent-harness chatgpt-web open
  agent-harness chatgpt-web repair

One-time UI setup remains intentionally manual:
1. Open Codex Web GPT.
2. Sign in inside its embedded ChatGPT browser.
3. Run the browser smoke test.
4. Install the ChatGPT Web models into Codex.
5. For local tools/memory access, use its MCP page to enable Full Harness.
6. Follow the upstream instructions to create the ChatGPT Developer Mode connector
   (currently named `Codex Native2`).
7. Restart Codex and start a fresh task.

Security note: this project is unofficial browser automation. Full Harness gives
ChatGPT Web turn-bound access to the current Codex tool surface. Keep normal Codex
approval controls enabled and do not expose raw database administration tools.
NEXT
