#!/usr/bin/env bash
# Installs Python 3 + pip + venv + pipx via apt.
#
# Must run as root (apt-get). NOT run automatically by install.sh -- like
# docker/setup.sh and cleanup/setup.sh, this needs root, which the regular
# unprivileged install.sh flow doesn't have.
#
# Usage:
#   sudo ~/dotfiles/python/setup.sh
#
# Safe to re-run: skips the apt install if everything's already present.
# ~/.local/bin (where pip --user and pipx install scripts) is already on
# PATH via zsh/exports/core/exports.zsh, conditional on the dir existing.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0" >&2
  exit 1
fi

PACKAGES=(python3 python3-pip python3-venv python3-dev pipx)

missing=()
for pkg in "${PACKAGES[@]}"; do
  dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done

if [ "${#missing[@]}" -eq 0 ]; then
  echo "==> Already installed, skipping: ${PACKAGES[*]}"
else
  echo "==> Installing: ${missing[*]}"
  apt-get update -qq
  apt-get install -y "${missing[@]}"
fi

echo "==> Done"
python3 --version
pip3 --version
pipx --version
