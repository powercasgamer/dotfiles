#!/usr/bin/env bash
# Client-side SSH hardening only -- safe to run as a normal user, no root
# needed. Server-side hardening is separate (ssh/harden-server.sh) since it
# needs root and can lock out remote access if done carelessly.
#
# Safe to re-run: only appends the Include line if it isn't already there,
# and never touches any Host blocks you've added to ~/.ssh/config yourself.
set -euo pipefail

SSH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/backup.sh
source "$SSH_DIR/../lib/backup.sh"
INCLUDE_LINE="Include $SSH_DIR/ssh_config"

echo "==> ~/.ssh permissions"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
mkdir -p "$HOME/.ssh/sockets"
chmod 700 "$HOME/.ssh/sockets"

echo "==> ~/.ssh/config"
snapshot_file "$HOME/.ssh/config"
touch "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"
if grep -qxF "$INCLUDE_LINE" "$HOME/.ssh/config" 2>/dev/null; then
  echo "    already included, skipping"
else
  # Appended, not prepended: ssh_config uses the FIRST match for each
  # parameter, so any Host-specific blocks you already have must stay
  # ahead of this catch-all default include, not be pushed after it.
  {
    echo ""
    echo "# Added by dotfiles/ssh/setup.sh -- portable defaults, see ssh/ssh_config"
    echo "$INCLUDE_LINE"
  } >> "$HOME/.ssh/config"
  echo "    added include line to the end of ~/.ssh/config"
fi
commit_snapshot "$HOME/.ssh/config"

# ssh_config sets `IdentitiesOnly yes` for every host, so ssh only offers
# keys named by an IdentityFile line or with a default name (id_ed25519,
# id_rsa, ...) -- even if the agent holds others. A machine that used to
# authenticate with, say, ~/.ssh/work via the agent stops working until
# that key gets an IdentityFile line. Point those out.
echo "==> Keys ssh will no longer offer on its own"
found=0
for key in "$HOME"/.ssh/*; do
  [ -f "$key" ] || continue
  head -n1 "$key" 2>/dev/null | grep -q -- '-----BEGIN .*PRIVATE KEY-----' || continue
  name="$(basename "$key")"
  case "$name" in
    id_rsa|id_ecdsa|id_ecdsa_sk|id_ed25519|id_ed25519_sk|id_dsa|id_xmss) continue ;;
  esac
  grep -qiE "^[[:space:]]*IdentityFile[[:space:]]+.*/$name\$" "$HOME/.ssh/config" && continue
  found=1
  echo "    ~/.ssh/$name has a non-default name and no IdentityFile line."
done
if [ "$found" -eq 1 ]; then
  echo "    If you use any of these, add a block ABOVE the Include line in"
  echo "    ~/.ssh/config, e.g. for GitHub:"
  echo "      Host github.com"
  echo "        IdentityFile ~/.ssh/<name>"
else
  echo "    none"
fi

echo "==> Done"
