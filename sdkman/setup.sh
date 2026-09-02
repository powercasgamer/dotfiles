#!/usr/bin/env bash
# Installs SDKMAN (https://sdkman.io) -- a candidate version manager for the
# JVM ecosystem (Java, Kotlin, Groovy, Gradle, Maven, sbt, Scala, ...).
#
# Unprivileged (installs into ~/.sdkman), so unlike docker/setup.sh,
# cleanup/setup.sh and python/setup.sh this runs automatically from
# install.sh -- no root required, same as git/setup.sh and ssh/setup.sh.
#
# The upstream installer wants to append its init snippet directly onto the
# end of ~/.zshrc. Here ~/.zshrc is a symlink into this tracked repo
# (zsh/zshrc), so instead the actual sourcing lives in
# zsh/exports/sdkman/sdkman.zsh (loaded automatically like every other
# exports/*.zsh file -- see the zshrc glob), and this script strips whatever
# the installer appended to zshrc so the tracked file stays clean.
#
# Safe to re-run: skips the download if SDKMAN is already installed.
set -euo pipefail

echo "==> SDKMAN"
if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
  echo "    already installed, skipping"
else
  for cmd in curl zip unzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Missing '$cmd'. Install it first, e.g.: sudo apt install -y $cmd"
      exit 1
    fi
  done
  curl -s "https://get.sdkman.io" | bash
fi

# Resolve through the symlink so we edit the real tracked file in place,
# rather than letting `sed -i` replace the ~/.zshrc symlink itself with a
# plain file (its default behavior when the target path is a symlink).
ZSHRC="$HOME/.zshrc"
[ -L "$ZSHRC" ] && ZSHRC="$(readlink -f "$ZSHRC")"

if [ -f "$ZSHRC" ] && grep -q 'sdkman-init.sh' "$ZSHRC"; then
  echo "==> Removing SDKMAN's auto-appended snippet from $ZSHRC"
  echo "    (handled instead by zsh/exports/sdkman/sdkman.zsh)"
  sed -i '/THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK/,/sdkman-init\.sh"$/d' "$ZSHRC"
  while [ -s "$ZSHRC" ] && [ -z "$(tail -n 1 "$ZSHRC")" ]; do
    sed -i '$ d' "$ZSHRC"
  done
fi

echo "==> Done"
