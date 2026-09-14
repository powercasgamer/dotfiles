#!/usr/bin/env bash
# Speeds up `apt update` by dropping in a config that skips downloading
# translation index files (Translation-en, etc.) -- they're only used for
# localized package descriptions, not for resolving or installing
# anything. Does not touch Install-Recommends/Suggests or any other apt
# default.
#
# Must run as root (writes to /etc/apt/apt.conf.d/). NOT run automatically
# by install.sh -- like docker/setup.sh and flatpak/setup.sh, this needs
# root, which the regular unprivileged install.sh flow doesn't have.
#
# Usage:
#   sudo ~/dotfiles/apt/setup.sh
#
# Safe to re-run: skips writing if the config is already in place, and
# backs up any pre-existing file at the destination first.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0" >&2
  exit 1
fi

APT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST=/etc/apt/apt.conf.d/99dotfiles-no-translations

if cmp -s "$APT_DIR/99dotfiles-no-translations" "$DEST" 2>/dev/null; then
  echo "==> apt speedup config already in place, skipping"
else
  if [ -e "$DEST" ]; then
    cp "$DEST" "$DEST.bak.$(date +%Y%m%d%H%M%S)"
    echo "    backed up existing $DEST"
  fi
  cp "$APT_DIR/99dotfiles-no-translations" "$DEST"
  echo "==> Wrote $DEST"
fi

echo "==> Done. apt update will now skip Translation-* index files."
