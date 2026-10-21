#!/usr/bin/env bash
# Installs Docker Engine + the Compose plugin from Docker's official apt
# repo, applies daemon hardening, and adds a user to the docker group.
#
# Must run as root (apt, systemctl, usermod). NOT run automatically by
# install.sh -- like tmux's system package and ssh/harden-server.sh, this
# needs root, which the regular unprivileged install.sh flow doesn't have.
#
# Usage:
#   sudo ~/dotfiles/docker/setup.sh [username]
#
# username defaults to $SUDO_USER (whoever ran sudo), or root when run as
# root without sudo -- in which case group membership is skipped, since
# root can use docker already.
#
# Being in the docker group is equivalent to passwordless root on this
# machine -- anyone in it can bind-mount the host filesystem into a
# container and read/write anything root can. Only add accounts that should
# have that level of access.
#
# Safe to re-run: skips the apt install if docker + compose are already
# present, and only restarts the daemon if daemon.json actually changed
# (live-restore keeps containers running across that restart regardless).
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0 [username]" >&2
  exit 1
fi

DOCKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/backup.sh
source "$DOCKER_DIR/../lib/backup.sh"
# Whoever ran sudo; or, logged in as root directly (no sudo, so no
# $SUDO_USER), root itself -- same fallback as cleanup.sh.
TARGET_USER="${1:-${SUDO_USER:-$(id -un)}}"

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  echo "==> Docker Engine + Compose already installed, skipping install"
else
  echo "==> Installing Docker Engine + Compose plugin"
  apt-get update -qq
  apt-get install -y ca-certificates curl gnupg

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # shellcheck disable=SC1091
  . /etc/os-release
  ARCH="$(dpkg --print-architecture)"
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -qq
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

echo "==> Enabling docker service"
systemctl enable --now docker >/dev/null

echo "==> Docker daemon hardening"
mkdir -p /etc/docker
if ! cmp -s "$DOCKER_DIR/daemon.json" /etc/docker/daemon.json 2>/dev/null; then
  backup_file /etc/docker/daemon.json cp
  cp "$DOCKER_DIR/daemon.json" /etc/docker/daemon.json
  systemctl restart docker
  echo "    daemon.json updated, docker restarted (live-restore kept containers up)"
else
  echo "    daemon.json already up to date, skipping restart"
fi

echo "==> docker group"
if [ "$(id -u "$TARGET_USER" 2>/dev/null)" = 0 ]; then
  echo "    $TARGET_USER is root, which can use docker already -- skipping."
  echo "    For another account: usermod -aG docker <username>"
else
  if id "$TARGET_USER" >/dev/null 2>&1; then
    usermod -aG docker "$TARGET_USER"
    echo "    added $TARGET_USER to the docker group"
    echo "    NOTE: docker group membership is root-equivalent on this machine."
    echo "    Log out/in (or run 'newgrp docker') for it to take effect."
  else
    echo "    user '$TARGET_USER' does not exist, skipping group membership"
  fi
fi

echo "==> Done"
docker --version
docker compose version
