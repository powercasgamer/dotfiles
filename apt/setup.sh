#!/usr/bin/env bash
# Speeds up `apt update` by dropping in configs that skip downloading
# index files apt itself never reads:
#   - 99dotfiles-no-translations: Translation-* files, only used for
#     localized package descriptions.
#   - 99dotfiles-no-appstream: AppStream (DEP-11) metadata, only used by
#     GUI software centers. Skipped if GNOME Software or KDE Discover is
#     installed, since they'd lose their apt app listings.
# Neither changes what gets resolved or installed. Does not touch
# Install-Recommends/Suggests or any other apt default.
#
# Must run as root (writes to /etc/apt/apt.conf.d/). NOT run automatically
# by install.sh -- like docker/setup.sh and flatpak/setup.sh, this needs
# root, which the regular unprivileged install.sh flow doesn't have.
#
# Usage:
#   sudo ~/dotfiles/apt/setup.sh
#
# Safe to re-run: skips writing a config that's already in place, and
# backs up any pre-existing file at the destination first.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0" >&2
  exit 1
fi

APT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_conf() {
  local name="$1" dest="/etc/apt/apt.conf.d/$1"
  if cmp -s "$APT_DIR/$name" "$dest" 2>/dev/null; then
    echo "==> $name already in place, skipping"
    return
  fi
  if [ -e "$dest" ]; then
    cp "$dest" "$dest.bak.$(date +%Y%m%d%H%M%S)"
    echo "    backed up existing $dest"
  fi
  cp "$APT_DIR/$name" "$dest"
  echo "==> Wrote $dest"
}

install_conf 99dotfiles-no-translations

if command -v gnome-software >/dev/null 2>&1 || command -v plasma-discover >/dev/null 2>&1; then
  echo "==> GUI software center found, leaving AppStream metadata enabled"
else
  install_conf 99dotfiles-no-appstream
fi

echo "==> Done. apt update will now skip index files apt doesn't use."
