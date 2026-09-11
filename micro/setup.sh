#!/usr/bin/env bash
# Installs micro (https://micro-editor.github.io) from Ubuntu's apt repo --
# a terminal editor that keeps nano's modeless "just start typing" feel
# (arrow keys, Ctrl+S save, Ctrl+C/V copy-paste) but adds real syntax
# highlighting, multiple cursors, and a plugin system, without vim/helix's
# modal learning curve. Also links settings.json into place.
#
# Must run as root (apt). NOT run automatically by install.sh -- like
# docker/setup.sh and gum/setup.sh, this needs root, which the regular
# unprivileged install.sh flow doesn't have.
#
# Usage:
#   sudo ~/dotfiles/micro/setup.sh [username]
#
# username is whose ~/.config/micro/settings.json gets linked; defaults to
# $SUDO_USER (whoever ran sudo) if not given. Resolved explicitly via
# getent rather than $HOME, since $HOME under sudo is root's home, not
# the invoking user's.
#
# Safe to re-run: skips the apt install if micro is already present, and
# backs up any pre-existing settings.json that isn't already our symlink.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0 [username]" >&2
  exit 1
fi

MICRO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${1:-${SUDO_USER:-}}"

if command -v micro >/dev/null 2>&1; then
  echo "==> micro already installed, skipping install"
else
  echo "==> Installing micro"
  apt-get update -qq
  apt-get install -y micro
fi

if [ -z "$TARGET_USER" ] || ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "==> No valid target user given (and \$SUDO_USER unset) -- skipping settings.json link."
  echo "    Link it yourself: ln -sf $MICRO_DIR/settings.json ~/.config/micro/settings.json"
else
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  TARGET_GROUP="$(id -gn "$TARGET_USER")"
  echo "==> Linking $TARGET_HOME/.config/micro/settings.json"
  install -o "$TARGET_USER" -g "$TARGET_GROUP" -d "$TARGET_HOME/.config/micro"
  if [ -e "$TARGET_HOME/.config/micro/settings.json" ] && [ ! -L "$TARGET_HOME/.config/micro/settings.json" ]; then
    mv "$TARGET_HOME/.config/micro/settings.json" "$TARGET_HOME/.config/micro/settings.json.bak.$(date +%Y%m%d%H%M%S)"
    echo "    backed up existing settings.json"
  fi
  ln -sf "$MICRO_DIR/settings.json" "$TARGET_HOME/.config/micro/settings.json"
  chown -h "$TARGET_USER:$TARGET_GROUP" "$TARGET_HOME/.config/micro/settings.json"
fi

echo "==> Done"
micro --version
