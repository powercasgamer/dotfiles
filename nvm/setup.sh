#!/usr/bin/env bash
# Installs nvm (https://github.com/nvm-sh/nvm) -- a version manager for
# Node.js.
#
# Unprivileged (installs into ~/.nvm), so like sdkman/setup.sh this runs
# automatically from install.sh -- no root required, same as git/setup.sh
# and ssh/setup.sh.
#
# The upstream installer wants to append its init snippet directly onto the
# end of a detected shell profile (~/.zshrc for a zsh login shell). Here
# ~/.zshrc is a symlink into this tracked repo (zsh/zshrc), so PROFILE=/dev/null
# tells the installer to skip touching any profile file entirely -- the
# actual sourcing lives in zsh/exports/node/nvm.zsh instead (loaded
# automatically like every other exports/*.zsh file).
#
# Safe to re-run: skips the download if nvm is already installed.
set -euo pipefail

NVM_VERSION="v0.40.7"

echo "==> nvm"
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  echo "    already installed, skipping"
else
  if ! command -v curl >/dev/null 2>&1; then
    echo "Missing 'curl'. Install it first, e.g.: sudo apt install -y curl"
    exit 1
  fi
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | PROFILE=/dev/null bash
fi

echo "==> Done"
