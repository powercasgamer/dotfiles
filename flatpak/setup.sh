#!/usr/bin/env bash
# Installs Flatpak from Ubuntu's apt repo and adds the Flathub remote, so
# `flatpak install flathub <app>` works out of the box. Does not install,
# replace, or migrate any existing apt packages -- purely additive.
#
# Must run as root (apt). NOT run automatically by install.sh -- like
# docker/setup.sh and micro/setup.sh, this needs root, which the regular
# unprivileged install.sh flow doesn't have.
#
# Usage:
#   sudo ~/dotfiles/flatpak/setup.sh
#
# Safe to re-run: skips the apt install if flatpak is already present, and
# skips adding the Flathub remote if it's already configured.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0" >&2
  exit 1
fi

if command -v flatpak >/dev/null 2>&1; then
  echo "==> flatpak already installed, skipping install"
else
  echo "==> Installing flatpak"
  apt-get update -qq
  apt-get install -y flatpak
fi

echo "==> Flathub remote"
if flatpak remote-list | grep -q '^flathub'; then
  echo "    already configured, skipping"
else
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  echo "    added"
fi

echo "==> Done"
flatpak --version
