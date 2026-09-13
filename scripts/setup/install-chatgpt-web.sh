#!/usr/bin/env bash
set -euo pipefail

URL="https://github.com/miuuyy/codex-chatgpt-web/releases/latest/download/install-launcher.sh"

if command -v codex-chatgpt-web >/dev/null 2>&1; then
  echo "codex-chatgpt-web CLI already exists: $(command -v codex-chatgpt-web)"
  echo "Run the launcher/upstream installer again manually if you want to force an update."
  exit 0
fi

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

echo "Executing the upstream codex-chatgpt-web launcher installer..."
sh "$TMP"

cat <<'NEXT'
Machine-side install finished.

One-time UI setup remains intentionally manual:
1. Open the codex-chatgpt-web launcher.
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
