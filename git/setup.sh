#!/usr/bin/env bash
# Git identity, sane defaults, git-lfs, and SSH commit/tag signing.
# Safe to re-run. Called from ../install.sh, but can be run standalone too.
set -euo pipefail

GIT_NAME="powercas_gamer"
GIT_EMAIL="cas@mizule.dev"
LFS_VERSION="3.7.1"
SIGNING_KEY="$HOME/.ssh/id_ed25519.pub"

echo "==> Git identity & defaults"
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global push.autoSetupRemote true
git config --global core.editor nano
git config --global rerere.enabled true
git config --global color.ui auto

echo "==> git-lfs"
if ! command -v git-lfs >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  tmpdir=$(mktemp -d)
  curl -fsSL -o "$tmpdir/git-lfs.tar.gz" \
    "https://github.com/git-lfs/git-lfs/releases/download/v${LFS_VERSION}/git-lfs-linux-amd64-v${LFS_VERSION}.tar.gz"
  tar xzf "$tmpdir/git-lfs.tar.gz" -C "$tmpdir"
  cp "$tmpdir/git-lfs-${LFS_VERSION}/git-lfs" "$HOME/.local/bin/git-lfs"
  chmod +x "$HOME/.local/bin/git-lfs"
  rm -rf "$tmpdir"
else
  echo "    already installed, skipping"
fi
export PATH="$HOME/.local/bin:$PATH"
git lfs install

echo "==> SSH commit/tag signing"
if [ -f "$SIGNING_KEY" ]; then
  git config --global gpg.format ssh
  git config --global user.signingkey "$SIGNING_KEY"
  git config --global commit.gpgsign true
  git config --global tag.gpgsign true

  printf '%s %s\n' "$GIT_EMAIL" "$(cat "$SIGNING_KEY")" > "$HOME/.ssh/allowed_signers"
  chmod 600 "$HOME/.ssh/allowed_signers"
  git config --global gpg.ssh.allowedSignersFile "$HOME/.ssh/allowed_signers"

  echo "    configured using $SIGNING_KEY"
  echo "    remember to add this key to GitHub as a 'Signing Key' too:"
  echo "    Settings -> SSH and GPG keys -> New SSH key -> Key type: Signing Key"
else
  echo "    no key found at $SIGNING_KEY"
  echo "    generate one with: ssh-keygen -t ed25519 -C \"$GIT_EMAIL\""
  echo "    or securely copy an existing keypair from another machine (e.g. via scp),"
  echo "    then re-run this script. Never commit a private key to this repo."
fi

echo "==> Done"
