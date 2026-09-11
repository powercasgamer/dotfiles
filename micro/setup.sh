#!/usr/bin/env bash
# Installs micro (https://micro-editor.github.io) from Ubuntu's apt repo --
# a terminal editor that keeps nano's modeless "just start typing" feel
# (arrow keys, Ctrl+S save, Ctrl+C/V copy-paste) but adds real syntax
# highlighting, multiple cursors, and a plugin system, without vim/helix's
# modal learning curve.
#
# Must run as root (apt). NOT run automatically by install.sh -- like
# docker/setup.sh and gum/setup.sh, this needs root, which the regular
# unprivileged install.sh flow doesn't have.
#
# Usage:
#   sudo ~/dotfiles/micro/setup.sh
#
# Safe to re-run: skips the apt install if micro is already present.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0" >&2
  exit 1
fi

if command -v micro >/dev/null 2>&1; then
  echo "==> micro already installed, skipping"
  micro --version
  exit 0
fi

echo "==> Installing micro"
apt-get update -qq
apt-get install -y micro

echo "==> Done"
micro --version
