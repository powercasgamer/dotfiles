#!/usr/bin/env bash
# Client-side SSH hardening only -- safe to run as a normal user, no root
# needed. Server-side hardening is separate (ssh/harden-server.sh) since it
# needs root and can lock out remote access if done carelessly.
#
# Safe to re-run: only appends the Include line if it isn't already there,
# and never touches any Host blocks you've added to ~/.ssh/config yourself.
set -euo pipefail

SSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INCLUDE_LINE="Include $SSH_DIR/ssh_config"

echo "==> ~/.ssh permissions"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
mkdir -p "$HOME/.ssh/sockets"
chmod 700 "$HOME/.ssh/sockets"

echo "==> ~/.ssh/config"
touch "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"
if grep -qxF "$INCLUDE_LINE" "$HOME/.ssh/config" 2>/dev/null; then
  echo "    already included, skipping"
else
  # Appended, not prepended: ssh_config uses the FIRST match for each
  # parameter, so any Host-specific blocks you already have must stay
  # ahead of this catch-all default include, not be pushed after it.
  {
    echo ""
    echo "# Added by dotfiles/ssh/setup.sh -- portable defaults, see ssh/ssh_config"
    echo "$INCLUDE_LINE"
  } >> "$HOME/.ssh/config"
  echo "    added include line to the end of ~/.ssh/config"
fi

echo "==> Done"
