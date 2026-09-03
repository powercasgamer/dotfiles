#!/usr/bin/env bash
# Installs uv (https://docs.astral.sh/uv/) -- a single fast binary that
# replaces pip, venv, pipx, and (optionally) even the python3 interpreter
# itself, via `uv venv`, `uv pip`, `uv tool install`, and `uv python install`.
#
# Unprivileged (installs into ~/.local/bin), so like sdkman/setup.sh and
# nvm/setup.sh this runs automatically from install.sh -- no root required,
# unlike python/setup.sh.
#
# The upstream installer wants to append a PATH snippet onto the end of a
# detected shell profile (~/.zshrc for a zsh login shell). Here ~/.zshrc is
# a symlink into this tracked repo (zsh/zshrc), so INSTALLER_NO_MODIFY_PATH=1
# tells it to skip touching any profile file entirely -- it installs the
# `uv`/`uvx` binaries straight into ~/.local/bin, which is already on PATH
# via zsh/exports/core/exports.zsh, so no dedicated exports/*.zsh is needed.
#
# Safe to re-run: skips the download if uv is already installed.
set -euo pipefail

echo "==> uv"
if [ -x "$HOME/.local/bin/uv" ]; then
  echo "    already installed, skipping"
else
  if ! command -v curl >/dev/null 2>&1; then
    echo "Missing 'curl'. Install it first, e.g.: sudo apt install -y curl"
    exit 1
  fi
  curl -LsSf https://astral.sh/uv/install.sh | env INSTALLER_NO_MODIFY_PATH=1 sh
fi

echo "==> Done"
