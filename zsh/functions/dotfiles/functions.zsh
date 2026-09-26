# Pull the latest dotfiles and re-run install.sh. Runs in a subshell so the
# current directory is left alone. --ff-only refuses to create a merge
# commit if this machine's copy has diverged -- sort that out by hand.
# Note install.sh skips tools that are already installed, so this applies
# config changes, not tool upgrades.
dotfiles-update() {
  (
    cd "$HOME/dotfiles" || return 1
    git pull --ff-only || return 1
    ./install.sh || return 1
  ) || return 1
  echo "==> Start a new shell to load the changes: exec zsh"
}
