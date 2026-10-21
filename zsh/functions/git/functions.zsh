# Switch to a branch and bring it up to date. Stops at the first failure
# (e.g. an unknown branch) instead of fetching/pulling into whatever branch
# was already checked out. --no-edit avoids getting parked in $EDITOR for a
# merge commit message.
gsfp() {
  if [ -z "$1" ]; then
    echo "Error: branch is required." >&2
    return 1
  fi
  git switch "$1" || return 1
  git fetch || return 1
  git pull --no-edit
}

# Format (gradle spotless), commit, push to main, and publish -- one shot
# for a gradle project release commit. Stops at the first failure so a
# failed format/build never gets committed, pushed, or published anyway.
gcpp() {
  if [ -z "$1" ]; then
    echo "Error: commit message is required." >&2
    return 1
  fi
  if [ ! -x ./gradlew ]; then
    echo "Error: no ./gradlew in the current directory." >&2
    return 1
  fi
  ./gradlew spotlessApply || return 1
  git add . || return 1
  git commit -m "$1" || return 1
  git push origin main || return 1
  ./gradlew publish
}

# Stage everything and commit, but only if there's actually something to
# commit -- avoids an empty/failed commit from running this out of habit.
gca() {
  if git diff --cached --quiet && git diff --quiet; then
    echo "No changes detected (staged or unstaged) - nothing to commit." >&2
    return 1
  fi
  git add . && git commit -m "$*"
}

# Same as gca, but tags the commit [ci skip].
gsca() {
  if git diff --cached --quiet && git diff --quiet; then
    echo "No changes detected (staged or unstaged) - nothing to commit." >&2
    return 1
  fi
  git add . && git commit -m "[ci skip] $*"
}

# Sync, stage, commit, and push to main in one step. Stops at the first
# failure so a bad pull/merge never gets committed and pushed anyway.
gpush() {
  git fetch || return 1
  git pull --no-edit || return 1
  if git diff --cached --quiet && git diff --quiet; then
    echo "No changes detected (staged or unstaged) - nothing to commit." >&2
    return 1
  fi
  git add . && git commit -m "$*" || return 1
  git push origin main
}

# Break down a repo's size: working tree, git object store, LFS (current
# checkout, all of history, local cache), and anything committed as a plain
# git blob at an LFS-tracked path -- i.e. large files from before LFS was
# adopted that still bloat the history until it's rewritten with
# `git lfs migrate import`. Pass a path to inspect a repo other than $PWD.
_gsize_h() { numfmt --to=iec-i --suffix=B "${1:-0}"; }

gsize() {
  local repo="${1:-.}"
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "Error: not a git repository: $repo" >&2
    return 1
  }
  local top gitdir
  top=$(git -C "$repo" rev-parse --show-toplevel) || return 1
  gitdir=$(git -C "$repo" rev-parse --absolute-git-dir) || return 1

  local -A cnt
  local k v
  while IFS=': ' read -r k v; do cnt[$k]=$v; done < <(git -C "$top" count-objects -v)


  echo "Repo:       $top"
  echo
  echo "Working tree (excl. .git):  $(du -sh --exclude=.git "$top" | cut -f1)"
  echo ".git directory total:       $(du -sh "$gitdir" | cut -f1)"
  echo "  packed objects:           $(_gsize_h $(( ${cnt[size-pack]:-0} * 1024 ))) (${cnt[in-pack]:-0} objects, ${cnt[packs]:-0} packs)"
  echo "  loose objects:            $(_gsize_h $(( ${cnt[size]:-0} * 1024 ))) (${cnt[count]:-0} objects)"
  [ "${cnt[size-garbage]:-0}" != 0 ] && echo "  garbage:                  $(_gsize_h $(( ${cnt[size-garbage]} * 1024 )))"

  # every blob reachable from any ref: type oid size size-on-disk path
  local blobs
  blobs=$(git -C "$top" rev-list --objects --all \
    | git -C "$top" cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(objectsize:disk) %(rest)' \
    | awk '$1 == "blob"')
  echo
  echo "History (all refs, unique blobs):"
  awk '{ n++; raw += $3; disk += $4 } END { printf "%d %d %d\n", n, raw, disk }' <<<"$blobs" \
    | read -r k raw disk
  echo "  blobs:                    $k ($(_gsize_h $raw) uncompressed, $(_gsize_h $disk) on disk)"

  if ! git lfs version >/dev/null 2>&1; then
    echo
    echo "git-lfs not installed -- skipping LFS breakdown."
    return 0
  fi

  local head_n head_b all_n all_b
  read -r head_n head_b < <(git -C "$top" lfs ls-files --json 2>/dev/null \
    | jq -r '[.files[]?] | "\(length) \(map(.size) | add // 0)"')
  read -r all_n all_b < <(git -C "$top" lfs ls-files --all --json 2>/dev/null \
    | jq -r '[.files[]?] | unique_by(.oid) | "\(length) \(map(.size) | add // 0)"')
  echo
  echo "LFS:"
  echo "  current checkout:         $(_gsize_h ${head_b:-0}) (${head_n:-0} files)"
  echo "  all of history:           $(_gsize_h ${all_b:-0}) (${all_n:-0} unique objects)"
  echo "  local cache (.git/lfs):   $( [ -d "$gitdir/lfs" ] && du -sh "$gitdir/lfs" | cut -f1 || echo 0B)"

  # Plain blobs at paths that are LFS-tracked *now*. Pointer files are ~130
  # bytes, so anything over 1KiB is real content committed before the path
  # was moved to LFS (or by a client without git-lfs installed).
  local pre
  pre=$(awk '$3 > 1024 { sub(/^([^ ]+ ){4}/, ""); print }' <<<"$blobs" \
    | git -C "$top" check-attr --stdin filter \
    | awk -F': filter: ' '$2 == "lfs" { print $1 }' \
    | awk 'NR == FNR { lfs[$0] = 1; next }
           { p = $0; sub(/^([^ ]+ ){4}/, "", p) }
           $3 > 1024 && (p in lfs) { n++; raw += $3; disk += $4 }
           END { printf "%d %d %d\n", n, raw, disk }' - <(print -r -- "$blobs"))
  read -r k raw disk <<<"$pre"
  local adopted
  adopted=$(git -C "$top" log --all --reverse -S'filter=lfs' --format='%h %as' \
    -- '.gitattributes' ':(glob)**/.gitattributes' 2>/dev/null | head -1)
  echo
  echo "Pre-LFS (plain git blobs at LFS-tracked paths):"
  echo "  LFS adopted:              ${adopted:-unknown}"
  if [ "$k" -gt 0 ]; then
    echo "  blobs:                    $k ($(_gsize_h $raw) uncompressed, $(_gsize_h $disk) on disk)"
    echo "  -> rewrite with: git lfs migrate import --everything --include='<patterns>'"
  else
    echo "  none -- history is clean"
  fi
  echo
  echo "Full size if nothing were in LFS: ~$(_gsize_h $(( (${cnt[size-pack]:-0} + ${cnt[size]:-0}) * 1024 + ${all_b:-0} ))) (git objects + all LFS objects)"

  # what GitHub reports for the remote, if this is a GitHub repo and gh is authed
  local remote_kb
  if command -v gh >/dev/null 2>&1 \
    && remote_kb=$(cd "$top" && timeout 10 gh repo view --json diskUsage -q .diskUsage 2>/dev/null) \
    && [ -n "$remote_kb" ]; then
    echo "GitHub-reported size:       $(_gsize_h $(( remote_kb * 1024 ))) (excludes LFS)"
  fi
}

# Move files to Git LFS. With no patterns, uses the ones already tracked in
# .gitattributes (handy for --rewrite after `git lfs track` was set up late).
#
#   glfs '*.jar' '*.zip'        track + convert the current files in a new
#                               commit; history keeps the old blobs
#   glfs --rewrite ['*.jar']    rewrite every local branch/tag so those files
#                               were always in LFS -- shrinks the repo, but
#                               needs a force-push and every clone to re-clone
#
# --rewrite saves a `git bundle` of all refs first and never pushes; it
# prints the push/cleanup commands to run once the result looks right.
glfs() {
  local rewrite=0
  if [ "$1" = "--rewrite" ]; then rewrite=1; shift; fi
  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "Error: not a git repository." >&2
    return 1
  }
  git lfs version >/dev/null 2>&1 || {
    echo "Error: git-lfs not installed (git/setup.sh installs it)." >&2
    return 1
  }
  local top
  top=$(git rev-parse --show-toplevel) || return 1
  cd "$top" || return 1

  # Both modes rewrite tracked files in place -- don't mix in local edits.
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Error: uncommitted changes -- commit or stash them first." >&2
    cd - >/dev/null; return 1
  fi

  local -a patterns
  if [ $# -gt 0 ]; then
    patterns=("$@")
  else
    patterns=(${(f)"$(git lfs track | awk '/^Listing excluded/ { exit } /^    / { print $1 }')"})
  fi
  if [ ${#patterns} -eq 0 ]; then
    echo "Usage: glfs [--rewrite] <pattern>...   e.g. glfs '*.jar'" >&2
    echo "No patterns given and none tracked yet. Largest file types in history:" >&2
    git lfs migrate info --everything --top=10 --skip-fetch >&2
    cd - >/dev/null; return 1
  fi
  local include="${(j:,:)patterns}"

  if [ $rewrite -eq 0 ]; then
    git lfs track "${patterns[@]}" || { cd - >/dev/null; return 1; }
    git add .gitattributes
    # re-run the (now LFS) clean filter over files already committed
    git add --renormalize . || { cd - >/dev/null; return 1; }
    if git diff --cached --quiet; then
      echo "Nothing to convert -- already tracked."
    else
      git commit -m "Track ${(j:, :)patterns} with Git LFS" || { cd - >/dev/null; return 1; }
      git show --stat --format='%h %s' HEAD
      echo
      echo "Old versions are still plain blobs in history; 'glfs --rewrite' removes them."
    fi
    cd - >/dev/null
    return 0
  fi

  echo "==> Will rewrite every local branch and tag, moving to LFS: $include"
  git lfs migrate info --everything --include="$include" --skip-fetch
  # migrate --everything only rewrites local refs; a branch that exists only
  # on the remote would be left with the old blobs (and keep them reachable)
  local orphans
  orphans=$(git for-each-ref --format='%(refname:short)' refs/remotes \
    | grep -v '/HEAD$' | while read -r r; do
        git show-ref --verify --quiet "refs/heads/${r#*/}" || echo "  $r"
      done)
  if [ -n "$orphans" ]; then
    echo
    echo "Remote branches with no local branch -- these will NOT be rewritten:"
    echo "$orphans"
    echo "(git switch <name> for each first, if they should be)"
  fi
  echo
  local answer
  read -r "answer?Rewrite history? [y/N] "
  if [[ "$answer" != [yY]* ]]; then
    cd - >/dev/null; return 1
  fi

  local backup="$HOME/.dotfiles-backups/git-lfs-migrate/${top:t}-$(date +%Y%m%d-%H%M%S).bundle"
  mkdir -p "${backup:h}" && chmod 700 "${backup:h:h}"
  git bundle create "$backup" --all || { cd - >/dev/null; return 1; }
  echo "==> Backup: $backup  (restore: git clone $backup)"

  git lfs migrate import --everything --include="$include" || {
    echo "Error: migrate failed -- refs unchanged or restore from $backup" >&2
    cd - >/dev/null; return 1
  }

  echo
  echo "==> Done locally. Check it (git log, gsize), then:"
  echo "  git push --force-with-lease --all && git push --force-with-lease --tags"
  echo "  git reflog expire --expire=now --all && git gc --prune=now   # reclaim local space"
  echo "Other clones must re-clone (or reset hard onto the rewritten branches)."
  echo "Until the push, origin/* still holds the old blobs, so gsize won't shrink yet."
  cd - >/dev/null
}
