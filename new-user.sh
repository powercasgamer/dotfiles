#!/usr/bin/env bash
# Creates a Linux user (if it doesn't exist yet) and applies the full
# dotfiles setup to their account: zsh + Oh My Zsh + plugins, aliases,
# git identity/defaults, git-lfs, SSH commit/tag signing, SDKMAN, nvm, uv.
#
# Must run as root (it calls useradd). Safe to re-run for an existing user
# -- it will not touch a dotfiles copy that's already there, just re-run
# install.sh against it.
#
# Usage:
#   sudo ./new-user.sh <username> [options]
#
#   --no-password        skip the interactive `passwd` prompt (account is
#                         created locked; set one later with `passwd <user>`)
#   --git-name NAME       the new user's git user.name (skips their prompt)
#   --git-email EMAIL     the new user's git user.email (skips their prompt)
#   --docker              add the user to the docker group, if it exists on
#                         this host. NOT the default -- docker group
#                         membership is root-equivalent (see docker/setup.sh),
#                         so it's opt-in per account rather than automatic.
#
# Without --git-name/--git-email, install.sh drops into an interactive
# prompt for git identity (see git/setup.sh) -- fine when you're running
# this directly in a terminal, needed up front for scripted/unattended use.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0 <username> [options]" >&2
  exit 1
fi

USERNAME="${1:?Usage: sudo $0 <username> [--no-password] [--git-name NAME] [--git-email EMAIL]}"
shift

SET_PASSWORD=1
NEW_GIT_NAME=""
NEW_GIT_EMAIL=""
ADD_DOCKER=0
while [ $# -gt 0 ]; do
  case "$1" in
    --no-password) SET_PASSWORD=0; shift ;;
    --git-name) NEW_GIT_NAME="${2:?--git-name needs a value}"; shift 2 ;;
    --git-email) NEW_GIT_EMAIL="${2:?--git-email needs a value}"; shift 2 ;;
    --docker) ADD_DOCKER=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

DOTFILES_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Checking system dependencies"
MISSING=()
for cmd in zsh git curl tmux zip unzip; do
  command -v "$cmd" >/dev/null 2>&1 || MISSING+=("$cmd")
done
if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "    installing: ${MISSING[*]}"
  apt-get update -qq
  apt-get install -y "${MISSING[@]}"
else
  echo "    zsh, git, curl, tmux, zip, unzip already present"
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
runuser -l "$USERNAME" -c "GIT_NAME=$(printf '%q' "$NEW_GIT_NAME") GIT_EMAIL=$(printf '%q' "$NEW_GIT_EMAIL") $(printf '%q' "$USER_HOME/dotfiles/install.sh")"

if [ "$ADD_DOCKER" -eq 1 ]; then
  echo "==> Docker group"
  if getent group docker >/dev/null 2>&1; then
    usermod -aG docker "$USERNAME"
    echo "    added $USERNAME to the docker group (root-equivalent on this host)"
  else
    echo "    docker group doesn't exist yet -- run docker/setup.sh first, or"
    echo "    re-run: sudo usermod -aG docker $USERNAME"
  fi
fi

echo "==> Done. Log in with: su - $USERNAME  (or ssh once a password/key is set)"
