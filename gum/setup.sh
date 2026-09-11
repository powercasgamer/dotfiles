#!/usr/bin/env bash
# Installs gum (https://github.com/charmbracelet/gum) from Charm's official
# apt repo -- a small terminal UI toolkit used by firewall/setup-firewall.sh
# for its interactive menu (gum choose/input/confirm).
#
# Must run as root (apt). NOT run automatically by install.sh -- like
# docker/setup.sh, this needs root, which the regular unprivileged
# install.sh flow doesn't have.
#
# Usage:
#   sudo ~/dotfiles/gum/setup.sh
#
# Safe to re-run: skips the apt install if gum is already present.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0" >&2
  exit 1
fi

if command -v gum >/dev/null 2>&1; then
  echo "==> gum already installed, skipping"
  gum --version
  exit 0
fi

echo "==> Adding Charm apt repo"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key -o /etc/apt/keyrings/charm.asc
chmod a+r /etc/apt/keyrings/charm.asc
echo "deb [signed-by=/etc/apt/keyrings/charm.asc] https://repo.charm.sh/apt/ * *" \
  > /etc/apt/sources.list.d/charm.list

echo "==> Installing gum"
apt-get update -qq
apt-get install -y gum

echo "==> Done"
gum --version
