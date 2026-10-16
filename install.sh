#!/usr/bin/env bash
# Sets up Oh My Zsh + this dotfiles/zsh config on a new machine.
# Safe to re-run.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/backup.sh
source "$DOTFILES_DIR/lib/backup.sh"
# One backup folder for the whole run, shared with every setup script below
# (see lib/backup.sh). Only created if something actually gets backed up.
DOTFILES_BACKUP_DIR="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
export DOTFILES_BACKUP_DIR
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Running as root (a server or container logged in as root, no sudo), the
# root-only steps below can just run, and the hints for opt-in ones drop
# the `sudo` prefix -- containers often don't have sudo at all.
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
  NOT_AUTO="opt-in, so not run automatically"
else
  SUDO="sudo "
  NOT_AUTO="needs root, so not run automatically here"
fi

if [ -z "$SUDO" ] && command -v apt-get >/dev/null 2>&1; then
  echo "==> Base packages (running as root, so installing them directly)"
  "$DOTFILES_DIR/packages/setup.sh"
fi

echo "==> Checking dependencies"
for cmd in zsh git curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing '$cmd'. Install the base packages first: ${SUDO}~/dotfiles/packages/setup.sh"
    exit 1
  fi
done

echo "==> Installing Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "    already installed, skipping"
fi

clone_plugin() {
  local repo="$1" dest="$2"
  if [ ! -d "$dest" ]; then
    git clone --depth=1 "$repo" "$dest"
  else
    echo "    $(basename "$dest") already present, skipping"
  fi
}

echo "==> Installing plugins"
clone_plugin https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_plugin https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_plugin https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"

echo "==> Linking ~/.zshrc"
[ -L "$HOME/.zshrc" ] || backup_file "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"

echo "==> Machine-local overrides / secrets"
if [ ! -e "$HOME/.zshrc.local" ]; then
  cp "$DOTFILES_DIR/zsh/zshrc.local.example" "$HOME/.zshrc.local"
  echo "    created ~/.zshrc.local from template"
else
  echo "    ~/.zshrc.local already exists, leaving it as-is"
fi
if [ ! -e "$HOME/.zshrc.secrets" ]; then
  cp "$DOTFILES_DIR/zsh/zshrc.secrets.example" "$HOME/.zshrc.secrets"
  chmod 600 "$HOME/.zshrc.secrets"
  echo "    created ~/.zshrc.secrets from template (chmod 600)"
else
  echo "    ~/.zshrc.secrets already exists, leaving it as-is"
fi

echo "==> Git config, git-lfs, SSH signing"
"$DOTFILES_DIR/git/setup.sh"

echo "==> tmux"
if command -v tmux >/dev/null 2>&1; then
  "$DOTFILES_DIR/tmux/setup.sh"
else
  echo "    tmux not installed, skipping. Install it and re-run this script, or"
  echo "    just run: ${SUDO}apt install -y tmux && ~/dotfiles/tmux/setup.sh"
fi

echo "==> nano config"
if command -v nano >/dev/null 2>&1; then
  "$DOTFILES_DIR/nano/setup.sh"
else
  echo "    nano not installed, skipping. Install it and re-run this script, or"
  echo "    just run: ${SUDO}apt install -y nano && ~/dotfiles/nano/setup.sh"
fi

echo "==> SSH client config"
"$DOTFILES_DIR/ssh/setup.sh"
echo "    (server-side hardening is separate and NOT run automatically --"
echo "    see ssh/harden-server.sh)"

echo "==> SDKMAN"
if command -v zip >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
  "$DOTFILES_DIR/sdkman/setup.sh"
else
  echo "    zip/unzip not installed ($NOT_AUTO):"
  echo "    ${SUDO}apt install -y zip unzip && ~/dotfiles/sdkman/setup.sh"
fi

echo "==> nvm"
"$DOTFILES_DIR/nvm/setup.sh"

echo "==> bun"
if command -v unzip >/dev/null 2>&1; then
  "$DOTFILES_DIR/bun/setup.sh"
else
  echo "    unzip not installed ($NOT_AUTO):"
  echo "    ${SUDO}apt install -y unzip && ~/dotfiles/bun/setup.sh"
fi

echo "==> pnpm"
"$DOTFILES_DIR/pnpm/setup.sh"

echo "==> Docker"
if command -v docker >/dev/null 2>&1; then
  echo "    already installed"
else
  echo "    not installed ($NOT_AUTO):"
  echo "    ${SUDO}~/dotfiles/docker/setup.sh"
fi

echo "==> Storage cleanup"
echo "    not installed ($NOT_AUTO):"
echo "    ${SUDO}~/dotfiles/cleanup/setup.sh"

echo "==> micro (optional editor)"
echo "    not installed ($NOT_AUTO):"
echo "    ${SUDO}~/dotfiles/micro/setup.sh"

echo "==> Flatpak (optional)"
if command -v flatpak >/dev/null 2>&1; then
  echo "    already installed"
else
  echo "    not installed ($NOT_AUTO):"
  echo "    ${SUDO}~/dotfiles/flatpak/setup.sh"
fi

echo "==> apt speedup (optional, skips translation index files on apt update)"
if [ -e /etc/apt/apt.conf.d/99dotfiles-no-translations ]; then
  echo "    already configured"
else
  echo "    not configured ($NOT_AUTO):"
  echo "    ${SUDO}~/dotfiles/apt/setup.sh"
fi

echo "==> Python 3"
if command -v python3 >/dev/null 2>&1; then
  echo "    already installed"
else
  echo "    python3 not installed ($NOT_AUTO):"
  echo "    ${SUDO}~/dotfiles/python/setup.sh"
fi

echo "==> uv"
"$DOTFILES_DIR/uv/setup.sh"

echo "==> Claude Code"
"$DOTFILES_DIR/claude/setup.sh"

echo "==> WakaTime"
if command -v unzip >/dev/null 2>&1; then
  "$DOTFILES_DIR/wakatime/setup.sh"
else
  echo "    unzip not installed ($NOT_AUTO):"
  echo "    ${SUDO}apt install -y unzip && ~/dotfiles/wakatime/setup.sh"
fi

echo "==> Done. Start a new zsh session with: exec zsh"
echo "    To make zsh your login shell: chsh -s \$(command -v zsh)"
