#!/usr/bin/env bash
# Sets up Oh My Zsh + this dotfiles/zsh config on a new machine.
# Safe to re-run.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

echo "==> Checking dependencies"
for cmd in zsh git curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing '$cmd'. Install it first, e.g.: sudo apt install -y zsh git curl"
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
if [ -e "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
  echo "    backed up existing ~/.zshrc"
fi
ln -sf "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"

echo "==> Git config, git-lfs, SSH signing"
"$DOTFILES_DIR/git/setup.sh"

echo "==> tmux"
if command -v tmux >/dev/null 2>&1; then
  "$DOTFILES_DIR/tmux/setup.sh"
else
  echo "    tmux not installed, skipping. Install it and re-run this script, or"
  echo "    just run: sudo apt install -y tmux && ~/dotfiles/tmux/setup.sh"
fi

echo "==> SSH client config"
"$DOTFILES_DIR/ssh/setup.sh"
echo "    (server-side hardening is separate and NOT run automatically --"
echo "    see ssh/harden-server.sh)"

echo "==> SDKMAN"
if command -v zip >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
  "$DOTFILES_DIR/sdkman/setup.sh"
else
  echo "    zip/unzip not installed (needs root, so not run automatically here):"
  echo "    sudo apt install -y zip unzip && ~/dotfiles/sdkman/setup.sh"
fi

echo "==> nvm"
"$DOTFILES_DIR/nvm/setup.sh"

echo "==> Docker"
if command -v docker >/dev/null 2>&1; then
  echo "    already installed"
else
  echo "    not installed (needs root, so not run automatically here):"
  echo "    sudo ~/dotfiles/docker/setup.sh"
fi

echo "==> Storage cleanup"
echo "    not installed (needs root, so not run automatically here):"
echo "    sudo ~/dotfiles/cleanup/setup.sh"

echo "==> Python 3"
if command -v python3 >/dev/null 2>&1 && command -v pip3 >/dev/null 2>&1 && command -v pipx >/dev/null 2>&1; then
  echo "    already installed"
else
  echo "    pip/venv/pipx not installed (needs root, so not run automatically here):"
  echo "    sudo ~/dotfiles/python/setup.sh"
fi

echo "==> Done. Start a new zsh session with: exec zsh"
echo "    To make zsh your login shell: chsh -s \$(command -v zsh)"
