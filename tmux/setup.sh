#!/usr/bin/env bash
# Symlinks ~/.tmux.conf into this repo and installs TPM + plugins.
# Safe to re-run. Called from ../install.sh, but can be run standalone too.
set -euo pipefail

TMUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is not installed. Install it first, e.g.: sudo apt install -y tmux"
  exit 1
fi

echo "==> Linking ~/.tmux.conf"
if [ -e "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
  mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak.$(date +%Y%m%d%H%M%S)"
  echo "    backed up existing ~/.tmux.conf"
fi
ln -sf "$TMUX_DIR/tmux.conf" "$HOME/.tmux.conf"

echo "==> Installing TPM (tmux plugin manager)"
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
  echo "    already installed, skipping"
fi

echo "==> Installing tmux plugins"
"$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null

echo "==> Done"
