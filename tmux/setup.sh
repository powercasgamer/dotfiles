#!/usr/bin/env bash
# Symlinks ~/.tmux.conf into this repo and installs TPM + plugins.
# Safe to re-run. Called from ../install.sh, but can be run standalone too.
set -euo pipefail

TMUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/backup.sh
source "$TMUX_DIR/../lib/backup.sh"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is not installed. Install it first, e.g.: sudo apt install -y tmux"
  exit 1
fi

echo "==> Linking ~/.tmux.conf"
[ -L "$HOME/.tmux.conf" ] || backup_file "$HOME/.tmux.conf"
ln -sf "$TMUX_DIR/tmux.conf" "$HOME/.tmux.conf"

echo "==> Installing TPM (tmux plugin manager)"
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
  echo "    already installed, skipping"
fi

# Cloned directly rather than via TPM's bin/install_plugins: that asks a
# running tmux server for TMUX_PLUGIN_MANAGER_PATH, which only exists once a
# server has loaded this config -- so it aborts on a fresh machine or
# whenever no tmux is running. A plugin install is just a clone into
# ~/.tmux/plugins/<name>, which is all this does. Updates still go
# through TPM inside tmux (<prefix> U).
echo "==> Installing tmux plugins"
grep -oE "^set -g @plugin '[^']+'" "$TMUX_DIR/conf.d/plugins.conf" | cut -d"'" -f2 |
  while read -r plugin; do
    dest="$HOME/.tmux/plugins/${plugin##*/}"
    if [ -d "$dest" ]; then
      echo "    ${plugin##*/} already present, skipping"
    else
      git clone --depth=1 "https://github.com/$plugin" "$dest"
    fi
  done

echo "==> Done"
