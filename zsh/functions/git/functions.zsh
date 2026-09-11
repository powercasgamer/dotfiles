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
