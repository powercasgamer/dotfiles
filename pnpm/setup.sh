#!/usr/bin/env bash
# Installs pnpm (https://pnpm.io) -- a fast, disk-space-efficient package
# manager for Node.js.
#
# Unprivileged (installs into ~/.local/share/pnpm), so like sdkman/setup.sh
# and nvm/setup.sh this runs automatically from install.sh -- no root
# required.
#
# The upstream installer runs `pnpm setup --force`, which unconditionally
# appends a PNPM_HOME + PATH snippet to ~/.zshrc. Since ~/.zshrc here is a
# symlink into this tracked repo, this script snapshots its line count
# before running the installer and truncates back to that afterward -- the
# actual sourcing lives in zsh/exports/node/pnpm.zsh instead (loaded the
# same way as every other exports/*.zsh file).
#
# Safe to re-run: skips the download if pnpm is already installed.
set -euo pipefail

echo "==> pnpm"
if [ -x "$HOME/.local/share/pnpm/pnpm" ]; then
  echo "    already installed, skipping"
else
  if ! command -v curl >/dev/null 2>&1; then
    echo "Missing 'curl'. Install it first, e.g.: sudo apt install -y curl"
    exit 1
  fi

  ZSHRC="$HOME/.zshrc"
  [ -L "$ZSHRC" ] && ZSHRC="$(readlink -f "$ZSHRC")"
  before_lines=0
  [ -f "$ZSHRC" ] && before_lines=$(wc -l < "$ZSHRC")

  curl -fsSL https://get.pnpm.io/install.sh | sh -

  if [ -f "$ZSHRC" ]; then
    after_lines=$(wc -l < "$ZSHRC")
    if [ "$after_lines" -gt "$before_lines" ]; then
      echo "==> Removing pnpm's auto-appended snippet from $ZSHRC"
      echo "    (handled instead by zsh/exports/node/pnpm.zsh)"
      head -n "$before_lines" "$ZSHRC" > "$ZSHRC.tmp" && mv "$ZSHRC.tmp" "$ZSHRC"
    fi
  fi
fi

echo "==> Done"
