#!/usr/bin/env bash
# Installs a weekly systemd timer that runs cleanup.sh as root, so it can
# also reclaim apt cache and vacuum the system journal (not just Docker).
#
# Must run as root (systemd system units). NOT run automatically by
# install.sh -- like docker/setup.sh and ssh/harden-server.sh, this needs
# root, which the regular unprivileged install.sh flow doesn't have.
#
# Usage:
#   sudo ~/dotfiles/cleanup/setup.sh [username]
#
# username is whose trash/thumbnail cache gets cleaned; defaults to
# $SUDO_USER (whoever ran sudo) if not given.
#
# Safe to re-run: overwrites the unit files and reloads systemd.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0 [username]" >&2
  exit 1
fi

CLEANUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${1:-${SUDO_USER:-}}"

if [ -z "$TARGET_USER" ] || ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "No valid target user given (and \$SUDO_USER unset)." >&2
  echo "Usage: sudo $0 <username>" >&2
  exit 1
fi

echo "==> Installing systemd units (target user: $TARGET_USER)"

cat > /etc/systemd/system/dotfiles-cleanup.service <<EOF
[Unit]
Description=dotfiles storage cleanup (docker, journal, apt, logs, trash)

[Service]
Type=oneshot
Environment=TARGET_USER=${TARGET_USER}
ExecStart=${CLEANUP_DIR}/cleanup.sh
Nice=19
IOSchedulingClass=idle
EOF

cat > /etc/systemd/system/dotfiles-cleanup.timer <<'EOF'
[Unit]
Description=Weekly dotfiles storage cleanup

[Timer]
OnCalendar=Sun *-*-* 03:30:00
RandomizedDelaySec=30m
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now dotfiles-cleanup.timer

echo "==> Done. Runs weekly (Sun 03:30, +/- 30m jitter)."
echo "    Run it immediately:  sudo systemctl start dotfiles-cleanup.service"
echo "    Dry run by hand:     ${CLEANUP_DIR}/cleanup.sh --dry-run"
echo "    View logs:           journalctl -u dotfiles-cleanup --since -30d"
echo "    Check next run:      systemctl list-timers dotfiles-cleanup.timer"
