#!/usr/bin/env bash
# Installs bun (https://bun.sh) -- a fast JS/TS runtime, bundler, test
# runner, and package manager.
#
# Unprivileged (installs into ~/.bun), so like sdkman/setup.sh and
# nvm/setup.sh this runs automatically from install.sh -- no root required.
#
# The upstream installer has no flag to skip modifying shell rc files -- it
# unconditionally appends a "# bun" block (BUN_INSTALL + PATH exports) to
# ~/.zshrc if the file is writable. Since ~/.zshrc here is a symlink into
# this tracked repo, this script snapshots its line count before running
# the installer and truncates back to that afterward -- the actual
# sourcing lives in zsh/exports/bun/bun.zsh instead (loaded the same way
# as every other exports/*.zsh file).
#
# Safe to re-run: skips the download if bun is already installed.
set -euo pipefail

echo "==> bun"
if [ -x "$HOME/.bun/bin/bun" ]; then
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

  curl -fsSL https://bun.sh/install | bash

  if [ -f "$ZSHRC" ]; then
    after_lines=$(wc -l < "$ZSHRC")
    if [ "$after_lines" -gt "$before_lines" ]; then
      echo "==> Removing bun's auto-appended snippet from $ZSHRC"
      echo "    (handled instead by zsh/exports/bun/bun.zsh)"
      head -n "$before_lines" "$ZSHRC" > "$ZSHRC.tmp" && mv "$ZSHRC.tmp" "$ZSHRC"
    fi
  fi
fi

echo "==> Done"
