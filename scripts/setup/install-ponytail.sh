#!/usr/bin/env bash
set -euo pipefail

warn() { printf 'WARN    %s\n' "$*" >&2; }
ok() { printf 'OK      %s\n' "$*"; }

installed=0

if command -v codex >/dev/null 2>&1; then
  echo "Installing/updating Ponytail for Codex..."
  codex plugin marketplace add DietrichGebert/ponytail >/dev/null 2>&1 || true
  if codex plugin add ponytail@ponytail; then
    ok "Ponytail installed for Codex"
  else
    warn "Codex Ponytail install returned non-zero; it may already be installed or the plugin interface may have changed."
  fi
  installed=1
fi

if command -v agy >/dev/null 2>&1; then
  echo "Installing/updating Ponytail for Antigravity CLI..."
  if agy plugin install https://github.com/DietrichGebert/ponytail; then
    ok "Ponytail installed for Antigravity"
  else
    warn "Antigravity Ponytail install returned non-zero; inspect the CLI output."
  fi
  installed=1
fi

if [[ "$installed" -eq 0 ]]; then
  warn "No supported Codex/Antigravity CLI detected; Ponytail was not installed."
  exit 0
fi

cat <<'NEXT'
Ponytail requires a one-time trust/review step on some hosts:
- Codex: open `/hooks`, review/trust the lifecycle hooks, then start a new thread.
- Antigravity: restart the agent if the plugin was installed during an active session.
NEXT
