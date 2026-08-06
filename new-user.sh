#!/usr/bin/env bash
# Creates a Linux user (if it doesn't exist yet) and applies the full
# dotfiles setup to their account: zsh + Oh My Zsh + plugins, aliases,
# git identity/defaults, git-lfs, SSH commit/tag signing.
#
# Must run as root (it calls useradd). Safe to re-run for an existing user
# -- it will not touch a dotfiles copy that's already there, just re-run
# install.sh against it.
#
# Usage:
#   sudo ./new-user.sh <username> [--no-password]
#
#   --no-password   skip the interactive `passwd` prompt (account is created
#                    locked; set a password for it later with `passwd <user>`)
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0 <username>" >&2
  exit 1
fi

USERNAME="${1:?Usage: sudo $0 <username> [--no-password]}"
SET_PASSWORD=1
[ "${2:-}" = "--no-password" ] && SET_PASSWORD=0

DOTFILES_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Checking system dependencies"
MISSING=()
for cmd in zsh git curl; do
  command -v "$cmd" >/dev/null 2>&1 || MISSING+=("$cmd")
done
if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "    installing: ${MISSING[*]}"
  apt-get update -qq
  apt-get install -y "${MISSING[@]}"
else
  echo "    zsh, git, curl already present"
fi

if id "$USERNAME" >/dev/null 2>&1; then
  echo "==> User '$USERNAME' already exists, skipping creation"
else
  echo "==> Creating user $USERNAME"
  useradd -m -s "$(command -v zsh)" "$USERNAME"
  if [ "$SET_PASSWORD" -eq 1 ]; then
    passwd "$USERNAME"
  else
    passwd -l "$USERNAME" >/dev/null
    echo "    account locked (--no-password); set one later with: passwd $USERNAME"
  fi
fi

USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)

echo "==> Dotfiles"
if [ -d "$USER_HOME/dotfiles" ]; then
  echo "    $USER_HOME/dotfiles already exists, leaving it as-is"
else
  echo "    copying $DOTFILES_SRC -> $USER_HOME/dotfiles"
  cp -r "$DOTFILES_SRC" "$USER_HOME/dotfiles"
  chown -R "$USERNAME:$USERNAME" "$USER_HOME/dotfiles"
fi

echo "==> Running install.sh as $USERNAME"
runuser -l "$USERNAME" -c "$USER_HOME/dotfiles/install.sh"

echo "==> Done. Log in with: su - $USERNAME  (or ssh once a password/key is set)"
