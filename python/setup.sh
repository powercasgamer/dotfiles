#!/usr/bin/env bash
# Installs python3 + python3-dev via apt.
#
# pip/venv/pipx are intentionally NOT installed here -- see uv/setup.sh
# (run automatically by install.sh, no root needed), which replaces all
# three: `uv venv` for virtualenvs, `uv pip` for package installs, and
# `uv tool install` for pipx-style isolated CLI tools. uv can even manage
# the Python interpreter itself (`uv python install 3.12`) if you'd rather
# not depend on apt's python3 at all.
#
# Must run as root (apt-get). NOT run automatically by install.sh -- like
# docker/setup.sh and cleanup/setup.sh, this needs root, which the regular
# unprivileged install.sh flow doesn't have.
#
# Usage:
#   sudo ~/dotfiles/python/setup.sh
#
# Safe to re-run: skips the apt install if everything's already present.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0" >&2
  exit 1
fi

PACKAGES=(python3 python3-dev)

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
