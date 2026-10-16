#!/usr/bin/env bash
# Installs the base apt packages the rest of this repo expects, so
# install.sh's per-tool "not installed, skipping" hints don't come up:
#
#   zsh git curl  -- hard requirements of install.sh itself
#   tmux nano     -- configured by tmux/setup.sh and nano/setup.sh
#   zip unzip     -- needed by sdkman/, bun/ and wakatime/setup.sh
#   jq            -- used by claude/setup.sh to edit ~/.claude/settings.json
#
# Must run as root (apt-get). NOT run automatically by install.sh -- like
# python/setup.sh and docker/setup.sh, this needs root, which the regular
# unprivileged install.sh flow doesn't have. Run it first on a new machine,
# then install.sh.
#
# Usage:
#   sudo ~/dotfiles/packages/setup.sh
#
# Safe to re-run: skips the apt install if everything's already present.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0" >&2
  exit 1
fi

PACKAGES=(zsh git curl tmux nano zip unzip jq)

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
