#!/usr/bin/env bash
# Symlinks ~/.nanorc into this repo.
# Safe to re-run. Called from ../install.sh, but can be run standalone too.
set -euo pipefail

NANO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/backup.sh
source "$NANO_DIR/../lib/backup.sh"

if ! command -v nano >/dev/null 2>&1; then
  echo "nano is not installed. Install it first, e.g.: sudo apt install -y nano"
  exit 1
fi

echo "==> Linking ~/.nanorc"
[ -L "$HOME/.nanorc" ] || backup_file "$HOME/.nanorc"
ln -sf "$NANO_DIR/nanorc" "$HOME/.nanorc"

echo "==> Done"
