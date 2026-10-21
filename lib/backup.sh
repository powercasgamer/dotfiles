# shellcheck shell=bash
# Sourced by the setup scripts, not run directly.
#
# Collects everything the scripts replace or edit into one backup folder,
# mirroring where each file lived, instead of leaving <file>.bak.<timestamp>
# copies scattered next to the originals:
#
#   ~/.dotfiles-backups/<YYYYmmdd-HHMMSS>/.zshrc
#   ~/.dotfiles-backups/<YYYYmmdd-HHMMSS>/.ssh/config
#   ~/.dotfiles-backups/<YYYYmmdd-HHMMSS>/etc/docker/daemon.json   (outside ~)
#
# install.sh exports DOTFILES_BACKUP_DIR up front, so every script in one
# run shares a folder; a script run standalone gets its own. The folder is
# only created once something is actually backed up. Root-only scripts
# back up into root's home; set DOTFILES_BACKUP_HOME to use another user's
# (micro/setup.sh does, for the user it links settings for).

# Sets _BACKUP_DEST to where <path> goes inside the backup folder, creating
# its parent. A variable, not stdout: run in $(...) the DOTFILES_BACKUP_DIR
# picked on first use would be lost with the subshell.
_backup_dest() {
  local src="$1" home rel
  home="${DOTFILES_BACKUP_HOME:-$HOME}"
  if [ -z "${DOTFILES_BACKUP_DIR:-}" ]; then
    DOTFILES_BACKUP_DIR="$home/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
    export DOTFILES_BACKUP_DIR
  fi
  case "$src" in
    "$home"/*) rel="${src#"$home"/}" ;;
    *)         rel="${src#/}" ;;
  esac
  _BACKUP_DEST="$DOTFILES_BACKUP_DIR/$rel"
  # Holds copies of ~/.gitconfig, ~/.ssh/config etc. -- owner-only.
  mkdir -p "$(dirname "$DOTFILES_BACKUP_DIR")"
  chmod 700 "$(dirname "$DOTFILES_BACKUP_DIR")"
  mkdir -p "$(dirname "$_BACKUP_DEST")"
}

# backup_file <path> [mv|cp]
#   Moves (default) or copies <path> into the backup folder. Use mv for a
#   file about to be replaced by a symlink, cp for one about to be
#   overwritten in place. No-op if <path> doesn't exist.
backup_file() {
  local src="$1" mode="${2:-mv}" dest
  [ -e "$src" ] || return 0
  _backup_dest "$src"
  dest="$_BACKUP_DEST"
  if [ "$mode" = cp ]; then
    cp -pL "$src" "$dest"
  else
    mv "$src" "$dest"
  fi
  echo "    backed up $src -> $dest"
}

# snapshot_file <path>, then later commit_snapshot <path>
#   For files edited in place on every run (~/.gitconfig, ~/.ssh/config):
#   snapshot before editing, and commit_snapshot keeps the pre-edit copy in
#   the backup folder only if the file actually changed -- so re-runs that
#   change nothing don't pile up identical backups.
declare -gA _DOTFILES_SNAPSHOTS=()

snapshot_file() {
  local tmp
  [ -e "$1" ] || return 0
  tmp="$(mktemp)"
  cp -pL "$1" "$tmp"
  _DOTFILES_SNAPSHOTS["$1"]="$tmp"
}

commit_snapshot() {
  local src="$1" tmp dest
  tmp="${_DOTFILES_SNAPSHOTS["$src"]:-}"
  [ -n "$tmp" ] || return 0
  unset '_DOTFILES_SNAPSHOTS[$src]'
  if cmp -s "$tmp" "$src"; then
    rm -f "$tmp"
    return 0
  fi
  _backup_dest "$src"
  dest="$_BACKUP_DEST"
  mv "$tmp" "$dest"
  echo "    backed up previous $src -> $dest"
}
