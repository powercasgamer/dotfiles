#!/usr/bin/env bash
# Installs Claude Code (https://code.claude.com) -- Anthropic's agentic
# coding CLI -- via the official native installer.
#
# Unprivileged (installs into ~/.local/bin, with versions kept under
# ~/.local/share/claude), so like uv/setup.sh and bun/setup.sh this runs
# automatically from install.sh -- no root required. The installer itself
# refuses to run under sudo.
#
# The installer finishes with `claude install`, which sets up "shell
# integration" and may append a PATH snippet to ~/.zshrc. Since ~/.zshrc is
# a symlink into this tracked repo, this script puts ~/.local/bin on PATH
# up front (so there's nothing to add) and, as a backstop, snapshots the
# file's line count and truncates back to it afterward -- same approach as
# bun/setup.sh. ~/.local/bin is already on PATH via
# zsh/exports/core/exports.zsh, so no dedicated exports/*.zsh is needed.
#
# Safe to re-run: skips the download if claude is already installed. Claude
# Code auto-updates itself after that.
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

echo "==> Claude Code"
if [ -x "$HOME/.local/bin/claude" ]; then
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

  curl -fsSL https://claude.ai/install.sh | bash

  if [ -f "$ZSHRC" ]; then
    after_lines=$(wc -l < "$ZSHRC")
    if [ "$after_lines" -gt "$before_lines" ]; then
      echo "==> Removing the installer's auto-appended snippet from $ZSHRC"
      echo "    (~/.local/bin is already on PATH via zsh/exports/core/exports.zsh)"
      head -n "$before_lines" "$ZSHRC" > "$ZSHRC.tmp" && mv "$ZSHRC.tmp" "$ZSHRC"
    fi
  fi
fi

echo "==> Done"
