#!/usr/bin/env bash
set -euo pipefail

# Optional Linux systemd --user scheduling of Orca's native skill updater.
NAME="agent-harness-orca-skills"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ORCA_CONTROL="$ROOT/scripts/setup/orca-control.sh"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE="$UNIT_DIR/$NAME.service"
TIMER="$UNIT_DIR/$NAME.timer"

usage() {
  cat <<'HELP'
agent-harness orca auto-update <status|enable|disable>

Disabled by default. On Linux systemd --user, refresh installed Orca
skills daily through the official Orca CLI. Other plugins are untouched.
HELP
}

command="${1:-status}"
case "$command" in
  help|-h|--help) usage; exit 0 ;;
  enable|disable|status) ;;
  *) usage >&2; exit 2 ;;
esac

if [[ "$(uname -s)" != "Linux" ]] || ! command -v systemctl >/dev/null 2>&1; then
  echo "This optional scheduler requires Linux systemd --user. Use Orca Skills UI otherwise." >&2
  exit 2
fi

is_owned() {
  [[ -f "$1" ]] && grep -qx '# Managed by agent-harness' "$1"
}
for unit in "$SERVICE" "$TIMER"; do
  if [[ -e "$unit" ]] && ! is_owned "$unit"; then
    echo "Refusing to touch user-owned unit: $unit" >&2
    exit 2
  fi
done

case "$command" in
  status)
    if [[ -f "$SERVICE" && -f "$TIMER" ]]; then
      systemctl --user is-enabled "$NAME.timer" || true
    else
      echo "disabled (no harness-managed timer)"
    fi
    ;;
  enable)
    bash "$ORCA_CONTROL" path >/dev/null
    # systemd expands specifiers (%) and quotes; reject unsafe unit path text.
    if printf %s "$ORCA_CONTROL" | LC_ALL=C grep -qE '["%[:cntrl:]]'; then
      echo "Unsupported character in harness path for systemd unit" >&2
      exit 2
    fi
    mkdir -p "$UNIT_DIR"
    cat > "$SERVICE" <<UNIT
# Managed by agent-harness
[Unit]
Description=Refresh installed Orca skills using Orca CLI

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash "$ORCA_CONTROL" update
UNIT
    cat > "$TIMER" <<UNIT
# Managed by agent-harness
[Unit]
Description=Daily Orca skill refresh

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true
Unit=$NAME.service

[Install]
WantedBy=timers.target
UNIT
    systemctl --user daemon-reload
    systemctl --user enable --now "$NAME.timer"
    echo "Enabled daily Orca skill refresh. Review systemctl --user list-timers."
    ;;
  disable)
    systemctl --user disable --now "$NAME.timer" 2>/dev/null || true
    rm -f "$SERVICE" "$TIMER"
    systemctl --user daemon-reload
    echo "Disabled harness-managed Orca skill refresh."
    ;;
esac
