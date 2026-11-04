#!/usr/bin/env bash
set -euo pipefail

# Optional Linux user-level scheduler. The update operation is delegated to
# Orca's official CLI; this harness does not download or overwrite skills.
NAME="agent-harness-orca-skills"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVICE_SCRIPT="$ROOT/scripts/setup/orca-control.sh"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SERVICE="$UNIT_DIR/$NAME.service"
TIMER="$UNIT_DIR/$NAME.timer"

usage() {
  cat <<'HELP'
agent-harness orca auto-update status
agent-harness orca auto-update enable
agent-harness orca auto-update disable

Linux systemd user timer, disabled by default. Only installed Orca skills
are refreshed with Orca's official 'skills update --all' implementation.
Ponytail/plugin and agentmemory runtime upgrades remain host-managed.
HELP
}

command="${1:-status}"
case "$command" in
  -h|--help|help) usage; exit 0 ;;
  enable|disable|status) ;;
  *) usage >&2; exit 2 ;;
esac

if [[ "$(uname -s)" != "Linux" ]] || ! command -v systemctl >/dev/null 2>&1; then
  echo "Orca skill auto-update scheduler needs Linux systemd --user; use Orca Skills UI on other hosts." >&2
  exit 2
fi

# Do not overwrite a systemd unit with the same name unless it is ours.
is_owned() {
  [[ -f "$1" ]] && grep -qx '# Managed by agent-harness' "$1"
}
for path in "$SERVICE" "$TIMER"; do
  if [[ -e "$path" ]] && ! is_owned "$path"; then
    echo "Refusing to touch non-harness unit: $path" >&2
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
    # Verify that the installed Orca CLI understands its own skill update
    # command before setting up unattended invocations.
    bash "$SERVICE_SCRIPT" path >/dev/null
    case "$SERVICE_SCRIPT" in
      *\"*|*$'\n'*|*%*)
        echo "Unsupported character in harness path for systemd unit" >&2
        exit 2
        ;;
    esac
    mkdir -p "$UNIT_DIR"
    cat > "$SERVICE" <<UNIT
# Managed by agent-harness
[Unit]
Description=Refresh installed Orca skills with Orca CLI

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash "$SERVICE_SCRIPT" update
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
    echo "Enabled daily Orca skill updates. Inspect systemctl --user list-timers."
    ;;
  disable)
    systemctl --user disable --now "$NAME.timer" 2>/dev/null || true
    rm -f "$SERVICE" "$TIMER"
    systemctl --user daemon-reload
    echo "Disabled harness-managed Orca skill update timer."
    ;;
esac
\n'* || "$SERVICE_SCRIPT" == *'%'* ]]; then
      echo "Unsupported character in harness path for systemd unit" >&2
      exit 2
    fi
    mkdir -p "$UNIT_DIR"
    cat > "$SERVICE" <<UNIT
# Managed by agent-harness
[Unit]
Description=Refresh installed Orca skills with Orca CLI

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash "$SERVICE_SCRIPT" update
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
    echo "Enabled daily Orca skill updates. Inspect systemctl --user list-timers."
    ;;
  disable)
    systemctl --user disable --now "$NAME.timer" 2>/dev/null || true
    rm -f "$SERVICE" "$TIMER"
    systemctl --user daemon-reload
    echo "Disabled harness-managed Orca skill update timer."
    ;;
esac
