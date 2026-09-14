#!/usr/bin/env bash
# Installs Flatpak from Ubuntu's apt repo and adds the Flathub remote, so
# `flatpak install flathub <app>` works out of the box. Does not install,
# replace, or migrate any existing apt packages -- purely additive.
#
# Also restricts auto-installed locale extensions to English -- by
# default Flatpak pulls every language pack for every app, which slows
# down installs/updates and wastes disk for locales you don't use.
#
# Must run as root (apt). NOT run automatically by install.sh -- like
# docker/setup.sh and micro/setup.sh, this needs root, which the regular
# unprivileged install.sh flow doesn't have.
#
# Usage:
#   sudo ~/dotfiles/flatpak/setup.sh
#
# Safe to re-run: skips the apt install if flatpak is already present,
# skips adding the Flathub remote if it's already configured, and the
# language restriction is idempotent.
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

echo "==> Restricting auto-installed locale extensions to English"
flatpak config --system --set languages "en"

echo "==> Done"
flatpak --version
