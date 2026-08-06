#!/usr/bin/env bash
# Applies server-side sshd hardening via a drop-in config file. Must run as
# root. NOT run automatically by install.sh, unlike the client-side
# ssh/setup.sh -- a bad sshd setting can lock you out of remote access, so
# this step is opt-in only, run it yourself when you're ready:
#
#   sudo ~/dotfiles/ssh/harden-server.sh
#
# Safe to re-run: re-copies sshd_hardening.conf (so edits to that file take
# effect), validates with `sshd -t` before touching the running service, and
# rolls back automatically if validation fails.
#
# PasswordAuthentication is intentionally left alone -- see the comment in
# ssh/sshd_hardening.conf. Flip it yourself once key-based login is
# confirmed working.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0" >&2
  exit 1
fi

if ! command -v sshd >/dev/null 2>&1; then
  echo "sshd is not installed -- nothing to harden." >&2
  exit 1
fi

SSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="/etc/ssh/sshd_config.d/99-dotfiles-hardening.conf"
BACKUP=""
if [ -e "$DEST" ]; then
  BACKUP="$(mktemp)"
  cp "$DEST" "$BACKUP"
fi

echo "==> Installing $DEST"
install -o root -g root -m 644 "$SSH_DIR/sshd_hardening.conf" "$DEST"

echo "==> Validating sshd config"
if ! sshd -t; then
  echo "sshd -t failed against the new config -- rolling back." >&2
  if [ -n "$BACKUP" ]; then
    mv "$BACKUP" "$DEST"
  else
    rm -f "$DEST"
  fi
  exit 1
fi
[ -n "$BACKUP" ] && rm -f "$BACKUP"

echo "==> Reloading sshd"
systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || service ssh reload

echo "==> Done. Effective settings:"
sshd -T | grep -iE "^(permitrootlogin|passwordauthentication|maxauthtries|x11forwarding|logingracetime)"
