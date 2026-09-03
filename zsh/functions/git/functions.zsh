# Switch to a branch and bring it up to date.
gsfp() {
  if [ -z "$1" ]; then
    echo "Error: branch is required." >&2
    return 1
  fi
  git switch "$1"
  git fetch
  git pull
}

# Format (gradle spotless), commit, push to main, and publish -- one shot
# for a gradle project release commit.
gcpp() {
  if [ -z "$1" ]; then
    echo "Error: commit message is required." >&2
    return 1
  fi
  ./gradlew spotlessApply
  git add .
  git commit -m "$1"
  git push origin main
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

# Sync, stage, commit, and push to main in one step.
gpush() {
  git fetch
  git pull
  git add .
  git commit -m "$*"
  git push origin main
}
