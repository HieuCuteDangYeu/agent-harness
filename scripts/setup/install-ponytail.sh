#!/usr/bin/env bash
set -euo pipefail

# The official Ponytail plugin owns its prompt, commands, and hooks.
# Never copy Ponytail's AGENTS.md over a project's AGENTS.md.
warn() { printf 'WARN    %s\n' "$*" >&2; }
ok() { printf 'OK      %s\n' "$*"; }

found=0

if command -v codex >/dev/null 2>&1; then
  found=1
  echo "Configuring official Ponytail plugin for Codex..."
  codex plugin marketplace add DietrichGebert/ponytail >/dev/null 2>&1 || true
  codex plugin add ponytail@ponytail &&
    ok "Codex Ponytail plugin installed" ||
    warn "Codex plugin setup returned nonzero; inspect existing plugin and /hooks"
fi

if command -v agy >/dev/null 2>&1; then
  found=1
  agy plugin install https://github.com/DietrichGebert/ponytail &&
    ok "Antigravity Ponytail skills installed" ||
    warn "Antigravity plugin install needs inspection"
fi

if command -v gemini >/dev/null 2>&1; then
  found=1
  gemini extensions install https://github.com/DietrichGebert/ponytail &&
    ok "Gemini Ponytail extension installed" ||
    warn "Gemini extension setup needs inspection"
fi

if command -v opencode >/dev/null 2>&1; then
  found=1
  opencode plugin add @dietrichgebert/ponytail &&
    ok "OpenCode Ponytail plugin installed" ||
    warn "OpenCode plugin setup needs inspection (check your OpenCode version)"
fi

if command -v copilot >/dev/null 2>&1; then
  found=1
  copilot plugin marketplace add DietrichGebert/ponytail >/dev/null 2>&1 || true
  copilot plugin install ponytail@ponytail &&
    ok "Copilot Ponytail plugin installed" ||
    warn "Copilot plugin setup needs inspection"
fi

if command -v pi >/dev/null 2>&1; then
  found=1
  pi install git:github.com/DietrichGebert/ponytail &&
    ok "Pi Ponytail plugin installed" ||
    warn "Pi plugin setup needs inspection"
fi

if command -v claude >/dev/null 2>&1; then
  found=1
  echo "Claude Code: in an interactive session use /plugin marketplace add DietrichGebert/ponytail"
  echo "then /plugin install ponytail@ponytail; enable marketplace auto-update in /plugin."
fi

if [[ "$found" -eq 0 ]]; then
  warn "No supported local Ponytail plugin host detected; install the official skill through your agent."
fi

cat <<'NEXT'
Ponytail is upstream-managed. Do not copy or duplicate its engineering prompt.
Restart the agent after plugin changes. In Codex, review and trust /hooks.
Use the agent's native plugin updater. For Claude Code, enable marketplace
auto-update under /plugin. Consult the upstream INSTALL.md for other agents.
NEXT
