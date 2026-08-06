#!/usr/bin/env bash
# Git identity, sane defaults, git-lfs, GitHub CLI, and SSH commit/tag signing.
# Safe to re-run. Called from ../install.sh, but can be run standalone too.
#
# Identity is never hardcoded here. Resolution order for each of name/email:
#   1. $GIT_NAME / $GIT_EMAIL env vars (for scripting, e.g. new-user.sh)
#   2. an already-configured global git user.name/user.email (left alone --
#      re-running this script won't re-prompt or overwrite your choice)
#   3. an interactive prompt (only if stdin is a TTY)
# If none of those apply (non-interactive, nothing set, no env var), identity
# and signing setup are skipped with an explanation rather than guessing.
set -euo pipefail

GIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LFS_VERSION="3.7.1"
GH_VERSION="2.97.0"
SIGNING_KEY="${SIGNING_KEY:-$HOME/.ssh/id_ed25519.pub}"

# Up front, not just after installing: makes the git-lfs presence check below
# reliable even when this script is run directly (bash git/setup.sh) in a
# shell that hasn't sourced .bashrc/.zshrc yet, so ~/.local/bin isn't on PATH.
export PATH="$HOME/.local/bin:$PATH"

echo "==> Git identity & defaults"
GIT_NAME="${GIT_NAME:-$(git config --global user.name || true)}"
GIT_EMAIL="${GIT_EMAIL:-$(git config --global user.email || true)}"

if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
  if [ -t 0 ]; then
    while [ -z "$GIT_NAME" ]; do
      read -rp "Git user.name (e.g. a display name, not necessarily your legal name): " GIT_NAME
    done
    while [ -z "$GIT_EMAIL" ]; do
      read -rp "Git user.email: " GIT_EMAIL
    done
  else
    echo "    no git identity configured and not running interactively -- skipping"
    echo "    identity & signing setup. Set \$GIT_NAME/\$GIT_EMAIL and re-run, or"
    echo "    run 'git config --global user.name/user.email' yourself first."
    GIT_NAME=""
    GIT_EMAIL=""
  fi
fi

if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
fi

git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global push.autoSetupRemote true
git config --global core.editor nano
git config --global rerere.enabled true
git config --global color.ui auto

echo "==> Global .gitignore / .gitattributes"
git config --global core.excludesfile "$GIT_DIR/gitignore_global"
git config --global core.attributesfile "$GIT_DIR/gitattributes_global"

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
git lfs install

echo "==> GitHub CLI (gh)"
if ! command -v gh >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  tmpdir=$(mktemp -d)
  curl -fsSL -o "$tmpdir/gh.tar.gz" \
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz"
  tar xzf "$tmpdir/gh.tar.gz" -C "$tmpdir"
  cp "$tmpdir/gh_${GH_VERSION}_linux_amd64/bin/gh" "$HOME/.local/bin/gh"
  chmod +x "$HOME/.local/bin/gh"
  rm -rf "$tmpdir"
else
  echo "    already installed, skipping"
fi
echo "    run 'gh auth login' to authenticate (not done automatically)"

echo "==> SSH commit/tag signing"
if [ -z "$GIT_EMAIL" ]; then
  echo "    skipped -- no git identity configured (see above)"
elif [ -f "$SIGNING_KEY" ]; then
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
